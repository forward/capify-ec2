require 'rubygems'
require 'fog'
require 'colored'

class CapifyEc2

  attr_accessor :load_balancer
  SLEEP_COUNT = 5

  def self.ec2_config
    YAML.load(File.new("config/ec2.yml"))
  end  
  
  def self.determine_regions(region = nil)
    regions = ec2_config[:aws_params][:regions] || [ec2_config[:aws_params][:region]]
    regions = [region] if region
    regions
  end
  
  def self.running_instances(region = nil)
    regions = determine_regions(region)
    instances = []
    regions.each do |region|
      ec2 = Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => ec2_config[:aws_access_key_id], :aws_secret_access_key => ec2_config[:aws_secret_access_key], :region => region)
      project_tag = ec2_config[:project_tag]
      running_instances = ec2.servers.select {|instance| instance.state == "running" && (project_tag.nil? || instance.tags["Project"] == project_tag) }
      running_instances.each do |instance|
        instance.instance_eval do
          def case_insensitive_tag(key)
            tags[key] || tags[key.downcase]
          end
        
          def name
            case_insensitive_tag("Name").split('-').reject {|portion| portion.include?(".")}.join("-")
          end
        
          def roles
            role = case_insensitive_tag("Role")
            roles = role.nil? ? [] : [role]
            if (roles_tag = case_insensitive_tag("Roles"))
              roles += case_insensitive_tag("Roles").split(/\s*,\s*/)
            end
            roles
          end
        end
        instances << instance
      end
    end
    instances
  end
  
  def self.instance_health(load_balancer, instance)
    elb.describe_instance_health(load_balancer.id, instance.id).body['DescribeInstanceHealthResult']['InstanceStates'][0]['State']
  end
  
  def self.get_instances_by_role(role, server_type)
    filter_instances_by_role(running_instances, role, server_type)
  end
  
  def self.get_instances_by_region(role, region)
    return unless region
    region_instances = running_instances(region)
    filter_instances_by_role(region_instances,role)
  end 
  
  def self.filter_instances_by_role(instances, role, server_type = nil)
    selected_instances = instances.select do |instance|
      server_roles = [instance.case_insensitive_tag("Role")] || []
      if (roles_tag = instance.case_insensitive_tag("Roles"))        
        server_roles += roles_tag.split(/\s*,\s*/)
      end
      server_type.nil? ? server_roles.member?(role.to_s) : (server_roles.member?(role.to_s) && server_type == role.to_s)
    end
  end 
  
  def self.get_instance_by_name(name)
    selected_instances = running_instances.select do |instance|
      value = instance.case_insensitive_tag("Name")
      value == name.to_s
    end.first
  end
  
  def self.server_names
    running_instances.map {|instance| instance.case_insensitive_tag("Name")}
  end
  
  def self.elb
    Fog::AWS::ELB.new(:aws_access_key_id => ec2_config[:aws_access_key_id], :aws_secret_access_key => ec2_config[:aws_secret_access_key], :region => ec2_config[:aws_params][:region])
  end 
  
  def self.get_load_balancer_by_instance(instance_id)
    hash = elb.load_balancers.inject({}) do |collect, load_balancer|
      load_balancer.instances.each {|load_balancer_instance_id| collect[load_balancer_instance_id] = load_balancer}
      collect
    end
    hash[instance_id]
  end
  
  def self.get_load_balancer_by_name(load_balancer_name)
    lbs = {}
    elb.load_balancers.each do |load_balancer|
      lbs[load_balancer.id] = load_balancer
    end
    lbs[load_balancer_name]

  end
     
  def self.deregister_instance_from_elb(instance_name)
    return unless ec2_config[:load_balanced]
    instance = get_instance_by_name(instance_name).first
    return if instance.nil?
    @@load_balancer = get_load_balancer_by_instance(instance.id)
    return if @@load_balancer.nil?

    elb.deregister_instances_from_load_balancer(instance.id, @@load_balancer.id)
  end
  
  def self.register_instance_in_elb(instance_name, load_balancer_name = '')
    return if !ec2_config[:load_balanced]
    instance = get_instance_by_name(instance_name).first
    return if instance.nil?
    load_balancer =  get_load_balancer_by_name(load_balancer_name) || @@load_balancer
    return if load_balancer.nil?

    elb.register_instances_with_load_balancer(instance.id, load_balancer.id)

    fail_after = ec2_config[:fail_after] || 30
    state = instance_health(load_balancer, instance)
    time_elapsed = 0
    
    while time_elapsed < fail_after
      break if state == "InService"
      sleep SLEEP_COUNT
      time_elapsed += SLEEP_COUNT
      STDERR.puts 'Verifying Instance Health'
      state = instance_health(load_balancer, instance)
    end
    if state == 'InService'
      STDERR.puts "#{instance.name}: Healthy"
    else
      STDERR.puts "#{instance.name}: tests timed out after #{time_elapsed} seconds."
    end
  end
end