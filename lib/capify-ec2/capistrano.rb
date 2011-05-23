require File.join(File.dirname(__FILE__), '../capify-ec2')

Capistrano::Configuration.instance(:must_exist).load do
  def ec2_role(role_to_define)
    defined_role = role_to_define.is_a?(Hash) ? role_to_define[:name] : role_to_define
    instances = CapifyEc2.get_instances_by_role(defined_role)
    subroles = role_to_define.is_a?(Hash) ? role_to_define[:options] : {}
    
    instances.each do |instance|
      task instance.name.to_sym do
        set :server_address, instance.dns_name
        role :web, *server_address
        role :app, *server_address
      end
    end
    
    task defined_role.to_sym do
      instances.each do |instance|
        new_options = {}
        subroles.each {|key, value| new_options[key] = true if value.to_s == instance.name}
        if new_options
          role defined_role.to_sym, instance.dns_name, new_options
        else
          role defined_role.to_sym, instance.dns_name
        end    
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
    CapifyEc2.register_instance_in_elb
  end
  
  task :date do
    run "date"
  end
  
  task :server_names do
    puts CapifyEc2.server_names.sort
  end
  
  namespace :deploy do
    before "deploy", "deregister_instance"
    after "deploy", "register_instance"
    after "deploy:rollback", "register_instance"
  end
end