require 'rubygems'
require 'fog'
require 'colored'
require File.expand_path(File.dirname(__FILE__) + '/capify-ec2/server')

class CapifyEc2

  attr_accessor :load_balancer, :instances
  
  unless const_defined? :SLEEP_COUNT
    SLEEP_COUNT = 5
  end
  
  def initialize(ec2_config = "config/ec2.yml")
    case ec2_config
    when Hash
      @ec2_config = ec2_config
    when String
      @ec2_config = YAML.load_file ec2_config
    else
      raise ArgumentError, "Invalid ec2_config: #{ec2_config.inspect}"
    end

    # Maintain backward compatibility with previous config format
    @ec2_config[:project_tags] ||= []
    # User can change the Roles tag string
    @ec2_config[:aws_roles_tag] ||= "Roles"
    @ec2_config[:aws_options_tag] ||= "Options"
    @ec2_config[:project_tags] << @ec2_config[:project_tag] if @ec2_config[:project_tag]
    
    regions = determine_regions()
    
    @instances = []
    regions.each do |region|
      Fog::Compute.new(:provider => 'AWS', 
                       :aws_access_key_id => @ec2_config[:aws_access_key_id], 
                       :aws_secret_access_key => @ec2_config[:aws_secret_access_key], 
                       :region => region).servers.each do |server|
        @instances << server if server.ready?
      end
    end
  end 
  
  def determine_regions()
    @ec2_config[:aws_params][:regions] || [@ec2_config[:aws_params][:region]]
  end
    
  def display_instances
    # Set minimum widths for the variable length instance attributes.
    column_widths = { :name_min => 4, :type_min => 4, :dns_min => 5, :roles_min => 5, :options_min => 6 }

    # Find the longest attribute across all instances, to format the columns properly.
    column_widths[:name]    = desired_instances.map{|i| i.name.to_s.ljust( column_widths[:name_min] )                               || ' ' * column_widths[:name_min]    }.max_by(&:length).length
    column_widths[:type]    = desired_instances.map{|i| i.flavor_id                                                                 || ' ' * column_widths[:type_min]    }.max_by(&:length).length
    column_widths[:dns]     = desired_instances.map{|i| i.contact_point.to_s.ljust( column_widths[:dns_min] )                       || ' ' * column_widths[:dns_min]     }.max_by(&:length).length
    column_widths[:roles]   = desired_instances.map{|i| i.tags[roles_tag].to_s.ljust( column_widths[:roles_min] ) || ' ' * column_widths[:roles_min]   }.max_by(&:length).length
    column_widths[:options] = desired_instances.map{|i| i.tags[options_tag].to_s.ljust( column_widths[:options_min] ) || ' ' * column_widths[:options_min] }.max_by(&:length).length

    # Title row.
    puts sprintf "%-3s   %s   %s   %s   %s   %s   %s   %s", 
      '',
      'Name'   .ljust( column_widths[:name]    ).bold,
      'ID'     .ljust( 10                      ).bold,
      'Type'   .ljust( column_widths[:type]    ).bold,
      'DNS'    .ljust( column_widths[:dns]     ).bold,
      'Zone'   .ljust( 10                      ).bold,
      'Roles'  .ljust( column_widths[:roles]   ).bold,
      'Options'.ljust( column_widths[:options] ).bold

    desired_instances.each_with_index do |instance, i|
      puts sprintf "%02d:   %-10s   %s   %s   %s   %-10s   %s   %s",
        i, 
        (instance.name || '')                             .ljust( column_widths[:name]    ).green,
        instance.id                                       .ljust( 2                       ).red,
        instance.flavor_id                                .ljust( column_widths[:type]    ).cyan,
        instance.contact_point                            .ljust( column_widths[:dns]     ).blue.bold,
        instance.availability_zone                        .ljust( 10                      ).magenta,
        (instance.tags[roles_tag] || '')                  .ljust( column_widths[:roles] ).yellow,
        (instance.tags[options_tag] || '')                .ljust( column_widths[:options] ).yellow
    end
  end

  def server_names
    desired_instances.map {|instance| instance.name}
  end
    
  def project_instances
    @instances.select {|instance| @ec2_config[:project_tags].include?(instance.tags["Project"])}
  end
  
  def desired_instances(region = nil)
    @ec2_config[:project_tags].empty? ? @instances : project_instances
  end
 
  def get_instances_by_role(role)
    desired_instances.select {|instance| instance.tags[roles_tag].split(%r{,\s*}).include?(role.to_s) rescue false}
  end
  
  def get_instances_by_region(roles, region)
    return unless region
    desired_instances.select {|instance| instance.availability_zone.match(region) && instance.tags['Roles'].split(%r{,\s*}).include?(roles.to_s) rescue false}
  end 
  
  def get_instance_by_name(name)
    desired_instances.select {|instance| instance.name == name}.first
  end
    
  def instance_health(load_balancer, instance)
    elb.describe_instance_health(load_balancer.id, instance.id).body['DescribeInstanceHealthResult']['InstanceStates'][0]['State']
  end
    
  def elb
    Fog::AWS::ELB.new(:aws_access_key_id => @ec2_config[:aws_access_key_id], :aws_secret_access_key => @ec2_config[:aws_secret_access_key], :region => @ec2_config[:aws_params][:region])
  end 
  
  def get_load_balancer_by_instance(instance_id)
    hash = elb.load_balancers.inject({}) do |collect, load_balancer|
      load_balancer.instances.each {|load_balancer_instance_id| collect[load_balancer_instance_id] = load_balancer}
      collect
    end
    hash[instance_id]
  end
  
  def get_load_balancer_by_name(load_balancer_name)
    lbs = {}
    elb.load_balancers.each do |load_balancer|
      lbs[load_balancer.id] = load_balancer
    end
    lbs[load_balancer_name]

  end
     
  def deregister_instance_from_elb(instance_name)
    return unless @ec2_config[:load_balanced]
    instance = get_instance_by_name(instance_name)
    return if instance.nil?
    @@load_balancer = get_load_balancer_by_instance(instance.id)
    return if @@load_balancer.nil?

    elb.deregister_instances_from_load_balancer(instance.id, @@load_balancer.id)
  end
  
  def register_instance_in_elb(instance_name, load_balancer_name = '')
    return if !@ec2_config[:load_balanced]
    instance = get_instance_by_name(instance_name)
    return if instance.nil?
    load_balancer =  get_load_balancer_by_name(load_balancer_name) || @@load_balancer
    return if load_balancer.nil?

    elb.register_instances_with_load_balancer(instance.id, load_balancer.id)

    fail_after = @ec2_config[:fail_after] || 30
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

  def roles_tag
    @ec2_config[:aws_roles_tag]
  end

  def options_tag
    @ec2_config[:aws_options_tag]
  end

end
