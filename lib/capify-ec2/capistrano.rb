require File.join(File.dirname(__FILE__), '../capify-ec2')
require 'colored'
require 'pp'

Capistrano::Configuration.instance(:must_exist).load do  
  def capify_ec2
    @capify_ec2 ||= CapifyEc2.new(fetch(:ec2_config, 'config/ec2.yml'))
  end

  namespace :ec2 do
    
    desc "Prints out all ec2 instances. index, name, instance_id, size, DNS/IP, region, tags"
    task :status do
      capify_ec2.display_instances
    end

    desc "Deregisters instance from its ELB"
    task :deregister_instance do
      instance_name = variables[:logger].instance_variable_get("@options")[:actions].first
      capify_ec2.deregister_instance_from_elb(instance_name)
    end

    desc "Registers an instance with an ELB."
    task :register_instance do
      instance_name = variables[:logger].instance_variable_get("@options")[:actions].first
      load_balancer_name = variables[:logger].instance_variable_get("@options")[:vars][:loadbalancer]
      capify_ec2.register_instance_in_elb(instance_name, load_balancer_name)
    end

    task :date do
      run "date"
    end

    desc "Prints list of ec2 server names"
    task :server_names do
      puts capify_ec2.server_names.sort
    end
    
    desc "Allows ssh to instance by id. cap ssh <INSTANCE NAME>"
    task :ssh do
      server = variables[:logger].instance_variable_get("@options")[:actions][1]
      instance = numeric?(server) ? capify_ec2.desired_instances[server.to_i] : capify_ec2.get_instance_by_name(server)
      port = ssh_options[:port] || 22 
      command = "ssh -p #{port} #{user}@#{instance.contact_point}"
      puts "Running `#{command}`"
      exec(command)
    end
  end

  namespace :deploy do
    before "deploy", "ec2:deregister_instance"
    after "deploy", "ec2:register_instance"
    after "deploy:rollback", "ec2:register_instance"
  end
    
  desc "Deploy to servers one at a time."
  task :rolling_deploy do
    puts "[Capify-EC2] Performing rolling deploy to servers one at a time..."

    deploy_targets = {}

    roles.each do |role|
      deploy_targets[ role[0] ] = []
      role[1].servers.each do |s|
        deploy_targets[ role[0] ] << { :dns => s.host.to_s, :options => s.options }
      end
    end

    # puts "Capistrano would normally deploy to all of these now... #{deploy_targets.inspect}"

    deploy_targets.each_pair do |a_role,servers|
      puts "[Capify-EC2] Processing role: #{a_role}"
      
      roles.clear

      servers.each do |server|
        current_node = capify_ec2.desired_instances.select { |instance| instance.dns_name == server[:dns] }
        unless current_node.empty?
          current_node_name = current_node.first.tags['Name'] ? "(#{current_node.first.tags['Name']})" : ''
        end

        roles[a_role].clear
        role a_role, server[:dns]

        current_server = "#{server[:dns]} #{current_node_name}"
        puts "[Capify-EC2] Beginning deployment to #{current_server}...".bold

        begin
          # Call the standard 'cap deploy' task with our redefined role containing a single server.
          top.deploy.default

          if server[:options][:healthcheck]
            options = {}
            options[:https]   = server[:options][:healthcheck][:https]   ||= false
            options[:timeout] = server[:options][:healthcheck][:timeout] ||= 60
            puts "[Capify-EC2] Starting healthcheck...".bold
            healthcheck = capify_ec2.instance_health_by_url( server[:dns],
                                                             server[:options][:healthcheck][:port], 
                                                             server[:options][:healthcheck][:path], 
                                                             server[:options][:healthcheck][:result], 
                                                             options )
            if healthcheck
              puts "[Capify-EC2] Deployment successful.".green.bold
            else
              puts "[Capify-EC2] Deployment failed!".red.bold
              raise "Healthcheck timeout exceeded"
            end
          end

        rescue => e
          puts "\n[Capify-EC2] Deployment aborted due to error: #{e}!".red.bold
          exit 1
        end


        #TODO: deploy stats on success/fails.
        #TODO: don't run the selfdeploy tagging?
      end
    end
  end

  def ec2_roles(*roles)
    server_name = variables[:logger].instance_variable_get("@options")[:actions].first unless variables[:logger].instance_variable_get("@options")[:actions][1].nil?
    
    if !server_name.nil? && !server_name.empty?
      named_instance = capify_ec2.get_instance_by_name(server_name)
  
      task named_instance.name.to_sym do
        remove_default_roles
        server_address = named_instance.contact_point

        if named_instance.respond_to?(:roles)
          roles = named_instance.roles
        else
          roles = [named_instance.tags["Roles"]].flatten
        end    
        
        roles.each do |role|
          define_role({:name => role, :options => {:on_no_matching_servers => :continue}}, named_instance)
        end
      end unless named_instance.nil?
    end
    roles.each {|role| ec2_role(role)}
  end
  
  def ec2_role(role_name_or_hash)
    role = role_name_or_hash.is_a?(Hash) ? role_name_or_hash : {:name => role_name_or_hash, :options => {}, :variables => {}}
        
    instances = capify_ec2.get_instances_by_role(role[:name])
    if role[:options] && role[:options].delete(:default)
      instances.each do |instance|
        define_role(role, instance)
      end
    end    
    regions = capify_ec2.determine_regions
    regions.each do |region|
      define_regions(region, role)
    end unless regions.nil?

    define_role_roles(role, instances)
    define_instance_roles(role, instances)
  end  

  def define_regions(region, role)
    instances = []
    @roles.each do |role_name, junk|
      region_instances = capify_ec2.get_instances_by_region(role_name, region)
      region_instances.each {|instance| instances << instance} unless region_instances.nil?
    end
    task region.to_sym do
      remove_default_roles
      instances.each do |instance|
        define_role(role, instance)
      end
    end
  end

  def define_instance_roles(role, instances)
    instances.each do |instance|
      task instance.name.to_sym do
        remove_default_roles
        define_role(role, instance)
      end
    end
  end

  def define_role_roles(role, instances)
    task role[:name].to_sym do
      remove_default_roles
      instances.each do |instance|
        define_role(role, instance)
      end
    end 
  end

  def define_role(role, instance)
    options     = role[:options] || {}
    variables   = role[:variables] || {}

    cap_options = options.inject({}) do |cap_options, (key, value)| 
      cap_options[key] = true if value.to_s == instance.name
      cap_options
    end 

    ec2_options = instance.tags["Options"] || ""
    ec2_options.split(%r{,\s*}).compact.each { |ec2_option|  cap_options[ec2_option.to_sym] = true }

    variables.each do |key, value| 
      set key, value
      cap_options[key] = value unless cap_options.has_key? key
    end

    role role[:name].to_sym, instance.contact_point, cap_options
  end
  
  def numeric?(object)
    true if Float(object) rescue false
  end
  
  def remove_default_roles	 	
    roles.reject! { true }
  end
  
end