require 'rubygems'
require 'fog'

class CapifyEc2

  def self.running_instances
    ec2_config = YAML.load(File.new("config/ec2.yml"))
    ec2 = Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => ec2_config[:aws_access_key_id], :aws_secret_access_key => ec2_config[:aws_secret_access_key], :region => ec2_config[:aws_params][:region])
    running_instances = ec2.servers.select {|instance| instance.state == "running"}
    running_instances.each do |instance|
      instance.instance_eval do
        def case_insensitive_tag(key)
          tags[key] || tags[key.downcase]
        end
        
        def name
          case_insensitive_tag("Name").split('-').reject {|portion| portion.include?(".")}.join("-")
        end
      end
    end
  end
  
  def self.get_instances_by_role(role)
    selected_instances = running_instances.select do |instance| 
      value = instance.case_insensitive_tag("Role")
      value == role.to_s
    end
  end  
  
  def self.get_instances_by_name(name)
    selected_instances = running_instances.select do |instance|
      value = instance.case_insensitive_tag("Name")
      value == name.to_s
    end
  end
  
  def self.server_names
    running_instances.map {|instance| instance.name}
  end 
  
end