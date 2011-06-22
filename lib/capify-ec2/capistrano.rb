require File.join(File.dirname(__FILE__), '../capify-ec2')
require 'colored'

Capistrano::Configuration.instance(:must_exist).load do
  def ec2_role(role_name_or_hash)
    role = role_name_or_hash.is_a?(Hash) ? role_name_or_hash : {:name => role_name_or_hash,:options => {}}
    instances = CapifyEc2.get_instances_by_role(role[:name])
    
    set :specified_roles, []
    
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
    instances = CapifyEc2.get_instances_by_role(role[:name], region)
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
        specified_roles << role[:name]
        remove_default_roles
        define_role(role, instance)
      end
    end
  end

  def define_role_roles(role, instances)
    task role[:name].to_sym do
      specified_roles << role[:name]
      instances.each do |instance|
        remove_default_roles
        define_role(role, instance)
      end
    end 
  end

  def remove_default_roles
    roles.reject! { |role_name, v| !specified_roles.member?(role_name) }
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
  
  def ec2_roles(*roles)
    roles.each {|role| ec2_role(role)}
  end
  
  task :deregister_instance do
    servers = variables[:logger].instance_variable_get("@options")[:actions].first
    CapifyEc2.deregister_instance_from_elb(servers)
  end
  
  task :register_instance do
    servers = variables[:logger].instance_variable_get("@options")[:actions].first
    load_balancer_name = variables[:logger].instance_variable_get("@options")[:vars][:loadbalancer]
    CapifyEc2.register_instance_in_elb(servers, load_balancer_name)
  end
  
  task :date do
    run "date"
  end
  
  task :server_names do
    puts CapifyEc2.server_names.sort
  end
  
  task :ec2_status do
    CapifyEc2.running_instances.each_with_index do |instance, i|
      puts sprintf "%-11s:   %-40s %-20s %-20s %-62s %-20s (%s)",
        i.to_s.magenta, instance.name, instance.id.red, instance.flavor_id.cyan,
        instance.dns_name.blue, instance.availability_zone.green, instance.roles.join(", ").yellow
    end
  end
  
  task :ssh do
    instances = CapifyEc2.running_instances
    instance = respond_to?(:i) ? instances[i.to_i] : instances.first
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