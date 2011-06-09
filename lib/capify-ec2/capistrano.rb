require File.join(File.dirname(__FILE__), '../capify-ec2')

Capistrano::Configuration.instance(:must_exist).load do
  def ec2_role(role_to_define)
    defined_role = role_to_define.is_a?(Hash) ? role_to_define[:name] : role_to_define
    instances = CapifyEc2.get_instances_by_role(defined_role)
    
    define_instance_roles(defined_role, instances)
    define_role_roles(defined_role, instances)
  end  

  def define_instance_roles(role_to_define, instances)
    instances.each do |instance|
      task instance.name.to_sym do
        set :server_address, instance.dns_name
        server instance.dns_name, role_to_define.to_sym
      end
    end
  end

  def define_role_roles(role_to_define, instances)
    task role_to_define.to_sym do
      instances.each do |instance|
        define_role(role_to_define, instance.dns_name)
      end
    end 
  end

  def define_role(role_to_define, dns_names)
    dns_names = [dns_names] if dns_names.is_a?(String)
    subroles = role_to_define.is_a?(Hash) ? role_to_define[:options] : {}
    new_options = {}
    subroles.each {|key, value| new_options[key] = true if value.to_s == instance.name}

    dns_names.each do |dns_name|
      if new_options
        role role_to_define.to_sym, dns_name, new_options
      else
        role role_to_define.to_sym, dns_name
      end
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
  
  namespace :deploy do
    before "deploy", "deregister_instance"
    after "deploy", "register_instance"
    after "deploy:rollback", "register_instance"
  end
end