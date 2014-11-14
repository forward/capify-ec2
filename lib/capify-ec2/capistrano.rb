require File.join(File.dirname(__FILE__), '../capify-ec2')
require 'colored'
require 'pp'

Capistrano::Configuration.instance(:must_exist).load do
  def capify_ec2
    @capify_ec2 ||= CapifyEc2.new(fetch(:ec2_config, 'config/ec2.yml'), fetch(:stage, ''))
  end

  namespace :ec2 do

    desc "Prints out all ec2 instances. index, name, instance_id, size, DNS/IP, region, tags"
    task :status do
      capify_ec2.display_instances
    end

    desc "Prints out all ec2 load balancers"
    task :elbs do
      capify_ec2.display_elbs
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
      if "ec2:ssh" == server then
        server = variables[:logger].instance_variable_get("@options")[:actions][2]
      end

      if server
        instance = numeric?(server) ? capify_ec2.desired_instances[server.to_i] : capify_ec2.get_instance_by_name(server)

        if instance and instance.contact_point then
          port = ssh_options.fetch(:port, 22)
          key = ""
          if ssh_options[:keys].is_a?(String) && !ssh_options[:keys].to_s.empty?
            key = "-i #{ssh_options[:keys]}"
          end
          if ssh_options[:keys].is_a?(Array) && ssh_options[:keys].length > 0
            key = "-i #{ssh_options[:keys].first}"
          end
          command = "ssh -p #{port} #{key} #{user}@#{instance.contact_point}"
          puts "Running `#{command}`"
          exec(command)
        else
          puts "[Capify-EC2] Error: No instances were found with instance number '#{server}'.".bold.red
          exit 1
        end
      else
        puts "[Capify-EC2] Error: You did not specify the instance number, which can be found via the 'ec2:status' command as follows:".bold.red
        top.ec2.status
      end
    end
  end

  namespace :deploy do
    before "deploy", "ec2:deregister_instance"
    after "deploy", "ec2:register_instance"
    after "deploy:rollback", "ec2:register_instance"
  end

  desc "Deploy to servers one at a time."
  task :rolling_deploy do
    puts "[Capify-EC2] Performing rolling deployment..."

    all_servers       = {}
    all_options       = {}

    roles.each do |role|
      role[1].servers.each do |s|
        server_dns = s.host.to_s
        all_servers[ server_dns ] ||= []
        all_servers[ server_dns ] << role[0]
        all_options[ role[0] ] ||= {}
        all_options[ role[0] ][ server_dns ] = (s.options || {})
      end
    end

    successful_deploys = []
    failed_deploys     = []

    # Here outside of the scope of the rescue so we can refer to it if a general exception is raised.
    load_balancer_to_reregister = nil

    begin

      # Fetch and set the real revision (eg/ Git ref) now, so any changes made to SCM during deployment will not be inadvertently included.
      puts "[Capify-EC2] Determining release revision..."
      set :revision, (fetch :real_revision)

      all_servers.each_with_index do |server,index|

        server_dns = server[0]
        server_roles = server[1]

        roles.clear

        load_balancer_to_reregister = nil # Set to nil again here, to ensure it always starts off nil for every iteration.
        is_load_balanced = false

        server_roles.each do |a_role|
          role a_role, server_dns, all_options[a_role][server_dns]
          is_load_balanced = true if all_options[a_role][server_dns][:load_balanced]
        end

        puts "[Capify-EC2]"
        puts "[Capify-EC2] (#{index+1} of #{all_servers.length}) Beginning deployment to #{instance_dns_with_name_tag(server_dns)} with #{server_roles.count > 1 ? 'roles' : 'role'} '#{server_roles.join(', ')}'...".bold

        unless dry_run
          load_balancer_to_reregister = capify_ec2.deregister_instance_from_elb_by_dns(server_dns) if is_load_balanced
        end

        # Call the standard 'cap deploy' task with our redefined role containing a single server.
        top.deploy.default

        server_roles.each do |a_role|

          # If healthcheck(s) are defined for this role, run them.
          if all_options[a_role][server_dns][:healthcheck]
            healthchecks_for_role = [ all_options[a_role][server_dns][:healthcheck] ].flatten

            puts "[Capify-EC2] Starting #{pluralise(healthchecks_for_role.size, 'healthcheck')} for role '#{a_role}'..."

            healthchecks_for_role.each_with_index do |healthcheck_for_role, i|
              options = {}
              options[:https]   = healthcheck_for_role[:https]   ||= false
              options[:timeout] = healthcheck_for_role[:timeout] ||= 60

              healthcheck = capify_ec2.instance_health_by_url( server_dns,
                                                               healthcheck_for_role[:port],
                                                               healthcheck_for_role[:path],
                                                               healthcheck_for_role[:result],
                                                               options )
              if healthcheck
                puts "[Capify-EC2] Healthcheck #{i+1} of #{healthchecks_for_role.size} for role '#{a_role}' successful.".green.bold
              else
                puts "[Capify-EC2] Healthcheck #{i+1} of #{healthchecks_for_role.size} for role '#{a_role}' failed!".red.bold
                raise CapifyEC2RollingDeployError.new("Healthcheck timeout exceeded", server_dns)
              end
            end
          end

        end

        if load_balancer_to_reregister
          reregistered = capify_ec2.reregister_instance_with_elb_by_dns(server_dns, load_balancer_to_reregister, 60)
          if reregistered
            puts "[Capify-EC2] Instance registration with ELB '#{load_balancer_to_reregister.id}' successful.".green.bold
          else
            puts "[Capify-EC2] Instance registration with ELB '#{load_balancer_to_reregister.id}' failed!".red.bold
            raise CapifyEC2RollingDeployError.new("ELB registration timeout exceeded", server_dns)
          end
        end

        puts "[Capify-EC2] Deployment successful to #{instance_dns_with_name_tag(server_dns)}.".green.bold
        successful_deploys << server_dns

      end
    rescue CapifyEC2RollingDeployError => e
      failed_deploys << e.dns
      puts "[Capify-EC2]"
      puts "[Capify-EC2] Deployment aborted due to error: #{e}!".red.bold
      puts "[Capify-EC2]" if load_balancer_to_reregister
      puts "[Capify-EC2] Note: Instance '#{instance_dns_with_name_tag(e.dns)}' was removed from the ELB '#{load_balancer_to_reregister.id}' and should be manually checked and reregistered.".red.bold if load_balancer_to_reregister

      rolling_deploy_status(all_servers, successful_deploys, failed_deploys)
      exit 1
    rescue => e
      failed_deploys << roles.values.first.servers.first.host
      puts "[Capify-EC2]"
      puts "[Capify-EC2] Deployment aborted due to error: #{e}!".red.bold
      puts "[Capify-EC2]" if load_balancer_to_reregister
      puts "[Capify-EC2] Note: Instance '#{instance_dns_with_name_tag(roles.values.first.servers.first.host)}' was removed from the ELB '#{load_balancer_to_reregister.id}' and should be manually checked and reregistered.".red.bold if load_balancer_to_reregister

      rolling_deploy_status(all_servers, successful_deploys, failed_deploys)
      exit 1
    else
      puts "[Capify-EC2]"
      puts "[Capify-EC2] Rolling deployment completed.".green.bold

      rolling_deploy_status(all_servers, successful_deploys, failed_deploys)
    end
  end

  def rolling_deploy_status(all_servers, successful_deploys, failed_deploys)
    puts "[Capify-EC2]"
    puts "[Capify-EC2]   Successful servers:"
    format_rolling_deploy_results( all_servers, successful_deploys )

    puts "[Capify-EC2]"
    puts "[Capify-EC2]   Failed servers:"
    format_rolling_deploy_results( all_servers, failed_deploys )

    puts "[Capify-EC2]"
    puts "[Capify-EC2]   Pending servers:"
    pending_deploys = (all_servers.keys - successful_deploys) - failed_deploys
    format_rolling_deploy_results( all_servers, pending_deploys )
  end

  def ec2_roles(*roles)
    server_name = variables[:logger].instance_variable_get("@options")[:actions].first unless variables[:logger].instance_variable_get("@options")[:actions][1].nil?

    if !server_name.nil? && !server_name.empty?
      named_instance = capify_ec2.get_instance_by_name(server_name)

      task named_instance.name.to_sym do
        server_address = named_instance.contact_point

        if named_instance.respond_to?(:roles)
          roles = named_instance.roles
        else
          roles = [named_instance.tags[ capify_ec2.ec2_config[:aws_roles_tag] ]].flatten
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
      instances.each do |instance|
        define_role(role, instance)
      end
    end
  end

  def define_instance_roles(role, instances)
    instances.each do |instance|
      task instance.name.to_sym do
        define_role(role, instance)
      end
    end
  end

  def define_role_roles(role, instances)
    task role[:name].to_sym do
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

    ec2_options = instance.tags[capify_ec2.ec2_config[:aws_options_tag]] || ""
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

  def pluralise(n, singular, plural=nil)
    if n == 1
        "#{singular}"
    elsif plural
        "#{plural}"
    else
        "#{singular}s"
    end
  end

end
