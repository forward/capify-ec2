require File.join(File.dirname(__FILE__), '../capify-ec2')
require 'colored'

Capistrano::Configuration.instance(:must_exist).load do
  def ec2_roles(*roles)
    server_type = variables[:logger].instance_variable_get("@options")[:actions].first unless variables[:logger].instance_variable_get("@options")[:actions][1].nil?
    
    named_instance = CapifyEc2.get_instance_by_name(server_type)
    task named_instance.name.to_sym do
      named_instance.roles.each do |role|
        define_role({:name => role, :options => {}}, named_instance)
      end
    end unless named_instance.nil?
    roles.each {|role| ec2_role(role, server_type)}
  end
  
  def ec2_role(role_name_or_hash, server_type)
    role = role_name_or_hash.is_a?(Hash) ? role_name_or_hash : {:name => role_name_or_hash,:options => {}}
    instances = CapifyEc2.get_instances_by_role(role[:name], server_type)
    if role[:options].delete(:default)
      instances.each do |instance|
        define_role(role, instance)
      end
    end
    
    regions = CapifyEc2.ec2_config[:aws_params][:regions] || [CapifyEc2.ec2_config[:aws_params][:region]]
    regions.each do |region|
      define_regions(region, role)
    end unless regions.nil?
    
    define_instance_roles(role, instances)    
    define_role_roles(role, instances)
  end  

  def define_regions(region, role)
    instances = CapifyEc2.get_instances_by_region(role[:name], region)
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
    subroles = role[:options]
    new_options = {}
    subroles.each {|key, value| new_options[key] = true if value.to_s == instance.name}

    if new_options
      role role[:name].to_sym, instance.dns_name, new_options 
    else
      role role[:name].to_sym, instance.dns_name
    end
  end
    
  def numeric?(object)
    true if Float(object) rescue false
  end
  
  desc "Deregisters instance from its ELB"
  task :deregister_instance do
    servers = variables[:logger].instance_variable_get("@options")[:actions].first
    CapifyEc2.deregister_instance_from_elb(servers)
  end
  
  desc "Registers an instance with an ELB."
  task :register_instance do
    servers = variables[:logger].instance_variable_get("@options")[:actions].first
    load_balancer_name = variables[:logger].instance_variable_get("@options")[:vars][:loadbalancer]
    CapifyEc2.register_instance_in_elb(servers, load_balancer_name)
  end
  
  task :date do
    run "date"
  end
  
  desc "Prints list of ec2 server names"
  task :server_names do
    puts CapifyEc2.server_names.sort
  end
  
  desc "Prints out all ec2 instances. index, name, instance_id, size, dns_name, region, tags"
  task :ec2_status do
    CapifyEc2.running_instances.each_with_index do |instance, i|
      puts sprintf "%-11s:   %-40s %-20s %-20s %-62s %-20s (%s)",
        i.to_s.magenta, instance.case_insensitive_tag("Name"), instance.id.red, instance.flavor_id.cyan,
        instance.dns_name.blue, instance.availability_zone.green, instance.roles.join(", ").yellow
    end
  end
  
  desc "Allows ssh to instance by id. cap ssh <INSTANCE NAME>"
  task :ssh do
    server = variables[:logger].instance_variable_get("@options")[:actions][1]
    instance = numeric?(server) ? CapifyEc2.running_instances[server.to_i] : CapifyEc2.get_instance_by_name(server)
    port = ssh_options[:port] || 22 
    command = "ssh -p #{port} #{user}@#{instance.dns_name}"
    puts "Running `#{command}`"
    system(command)
  end
  
  namespace :deploy do
    before "deploy", "deregister_instance"
    after "deploy", "register_instance"
    after "deploy:rollback", "register_instance"
  end
  
end