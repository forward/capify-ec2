require 'rubygems'
require 'fog'

class CapifyEc2

  attr_accessor :ec2_config, :instance, :elb_name, :elb
  
  def self.running_instances
    @ec2_config = YAML.load(File.new("config/ec2.yml"))
    ec2 = Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => @ec2_config[:aws_access_key_id], :aws_secret_access_key => @ec2_config[:aws_secret_access_key], :region => @ec2_config[:aws_params][:region])
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
  
  def self.get_instance_by_name(name)
    selected_instances = running_instances.select do |instance|
      value = instance.case_insensitive_tag("Name")
      value == name.to_s
    end
  end
  
  def self.server_names
    running_instances.map {|instance| instance.name}
  end
  
  def self.get_elb_name_by_instance(instance_id)
    @elb = Fog::AWS::ELB.new(:aws_access_key_id => @ec2_config[:aws_access_key_id], :aws_secret_access_key => @ec2_config[:aws_secret_access_key], :region => @ec2_config[:aws_params][:region])
    @elb.load_balancers.each do |load_balancer|
      p load_balancer
      load_balancer.instances.each {|instance| return load_balancer.id if instance_id == instance}
    end
    return nil
  end
     
  def self.deregister_instance_from_elb(instance_name)
    return unless @ec2_config[:load_balanced]
    @instance = get_instance_by_name(instance_name).first
    @elb_name = get_elb_name_by_instance(@instance.id)
    @elb.deregister_instances_from_load_balancer(@instance.id, @elb_name) unless @elb_name.nil?
  end
  
    def self.register_instance_in_elb
      return unless @ec2_config[:load_balanced]
      fail_after = !@ec2_config[:fail_after].nil? ? @ec2_config[:fail_after] : 30
      @elb.register_instances_with_load_balancer(@instance.id, @elb_name) unless @elb_name.nil?
      state = @elb.describe_instance_health(@elb_name, @instance.id).body['DescribeInstanceHealthResult']['InstanceStates'][0]['State']
      time_elapsed = 0
      sleepcount = 5
      until (state == 'InService' || time_elapsed >= fail_after)
        sleep sleepcount
        time_elapsed += sleepcount
        puts 'Verifying Instance Health'
        state = @elb.describe_instance_health(@elb_name, @instance.id).body['DescribeInstanceHealthResult']['InstanceStates'][0]['State']
      end
      if state == 'InService'
        puts "#{@instance.tags['Name']}: Healthy"
      else
        puts "#{@instance.tags['Name']}: tests timed out after #{time_elapsed} seconds."
      end
    end
  end