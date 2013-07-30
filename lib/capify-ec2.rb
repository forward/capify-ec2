require 'rubygems'
require 'fog'
require 'colored'
require 'net/http'
require 'net/https'
require File.expand_path(File.dirname(__FILE__) + '/capify-ec2/server')

class CapifyEc2

  attr_accessor :load_balancer, :instances, :ec2_config

  unless const_defined? :SLEEP_COUNT
    SLEEP_COUNT = 5
  end

  def initialize(ec2_config = "config/ec2.yml", stage = '')
    case ec2_config
    when Hash
      @ec2_config = ec2_config
    when String
      @ec2_config = YAML.load_file ec2_config
    else
      raise ArgumentError, "Invalid ec2_config: #{ec2_config.inspect}"
    end
    @ec2_config[:stage] = stage

    # Maintain backward compatibility with previous config format
    @ec2_config[:project_tags] ||= []
    # User can change the Project tag string
    @ec2_config[:aws_project_tag] ||= "Project"
    # User can change the Roles tag string
    @ec2_config[:aws_roles_tag] ||= "Roles"
    # User can change the Options tag string.
    @ec2_config[:aws_options_tag] ||= "Options"
    # User can change the Stages tag string
    @ec2_config[:aws_stages_tag] ||= "Stages"

    @ec2_config[:project_tags] << @ec2_config[:project_tag] if @ec2_config[:project_tag]

    regions = determine_regions()

    @instances = []

    regions.each do |region|
      begin
        servers = Fog::Compute.new( {:provider => 'AWS', :region => region}.merge!(security_credentials) ).servers
      rescue => e
        puts "[Capify-EC2] Unable to connect to AWS: #{e}.".red.bold
        exit 1
      end
      
      servers.each do |server|
        @instances << server if server.ready?
      end
    end
  end

  def security_credentials
    if @ec2_config[:use_iam_profile]
      { :use_iam_profile       => true }
    else
      { :aws_access_key_id     => aws_access_key_id,
        :aws_secret_access_key => aws_secret_access_key }
    end
  end
  
  def determine_regions()
    @ec2_config[:aws_params][:regions] || [@ec2_config[:aws_params][:region]]
  end

  def aws_access_key_id
    @ec2_config[:aws_access_key_id] || Fog.credentials[:aws_access_key_id] || ENV['AWS_ACCESS_KEY_ID'] || @ec2_config[:use_iam_profile] || raise("Missing AWS Access Key ID")
  end

  def aws_secret_access_key
    @ec2_config[:aws_secret_access_key] || Fog.credentials[:aws_secret_access_key] || ENV['AWS_SECRET_ACCESS_KEY'] || @ec2_config[:use_iam_profile] || raise("Missing AWS Secret Access Key")
  end

  def display_instances
    unless desired_instances and desired_instances.any?
      puts "[Capify-EC2] No instances were found using your 'ec2.yml' configuration.".red.bold
      return
    end

    # Set minimum widths for the variable length instance attributes.
    column_widths = { :name_min => 4, :type_min => 4, :dns_min => 5, :roles_min => @ec2_config[:aws_roles_tag].length, :stages_min => @ec2_config[:aws_stages_tag].length, :options_min => @ec2_config[:aws_options_tag].length }

    # Find the longest attribute across all instances, to format the columns properly.
    column_widths[:name]    = desired_instances.map{|i| i.name.to_s.ljust( column_widths[:name_min] )                                   || ' ' * column_widths[:name_min]    }.max_by(&:length).length
    column_widths[:type]    = desired_instances.map{|i| i.flavor_id                                                                     || ' ' * column_widths[:type_min]    }.max_by(&:length).length
    column_widths[:dns]     = desired_instances.map{|i| i.contact_point.to_s.ljust( column_widths[:dns_min] )                           || ' ' * column_widths[:dns_min]     }.max_by(&:length).length
    column_widths[:roles]   = desired_instances.map{|i| i.tags[@ec2_config[:aws_roles_tag]].to_s.ljust( column_widths[:roles_min] )     || ' ' * column_widths[:roles_min]   }.max_by(&:length).length
    column_widths[:stages]  = desired_instances.map{|i| i.tags[@ec2_config[:aws_stages_tag]].to_s.ljust( column_widths[:stages_min] )   || ' ' * column_widths[:stages_min]  }.max_by(&:length).length
    column_widths[:options] = desired_instances.map{|i| i.tags[@ec2_config[:aws_options_tag]].to_s.ljust( column_widths[:options_min] ) || ' ' * column_widths[:options_min] }.max_by(&:length).length

    roles_present   = desired_instances.map{|i| i.tags[@ec2_config[:aws_roles_tag]].to_s}.max_by(&:length).length > 0
    options_present = desired_instances.map{|i| i.tags[@ec2_config[:aws_options_tag]].to_s}.max_by(&:length).length > 0
    stages_present  = desired_instances.map{|i| i.tags[@ec2_config[:aws_stages_tag]].to_s}.max_by(&:length).length > 0

    # Project and Stages info..
    info_label_width = [@ec2_config[:aws_project_tag], @ec2_config[:aws_stages_tag]].map(&:length).max
    puts "#{@ec2_config[:aws_project_tag].rjust( info_label_width ).bold}: #{@ec2_config[:project_tags].join(', ')}." if @ec2_config[:project_tags].any?
    puts "#{@ec2_config[:aws_stages_tag].rjust( info_label_width ).bold}: #{@ec2_config[:stage]}." unless @ec2_config[:stage].to_s.empty?
    
    # Title row.
    status_output = []
    status_output << 'Num'                                                         .bold
    status_output << 'Name'                       .ljust( column_widths[:name]    ).bold
    status_output << 'ID'                         .ljust( 10                      ).bold
    status_output << 'Type'                       .ljust( column_widths[:type]    ).bold
    status_output << 'DNS'                        .ljust( column_widths[:dns]     ).bold
    status_output << 'Zone'                       .ljust( 10                      ).bold
    status_output << @ec2_config[:aws_stages_tag] .ljust( column_widths[:stages]  ).bold if stages_present
    status_output << @ec2_config[:aws_roles_tag]  .ljust( column_widths[:roles]   ).bold if roles_present
    status_output << @ec2_config[:aws_options_tag].ljust( column_widths[:options] ).bold if options_present
    puts status_output.join("   ")
    
    desired_instances.each_with_index do |instance, i|
      status_output = []
      status_output << "%02d:" % i
      status_output << (instance.name || '')                               .ljust( column_widths[:name]    ).green
      status_output << instance.id                                         .ljust( 2                       ).red
      status_output << instance.flavor_id                                  .ljust( column_widths[:type]    ).cyan
      status_output << instance.contact_point                              .ljust( column_widths[:dns]     ).blue.bold
      status_output << instance.availability_zone                          .ljust( 10                      ).magenta
      status_output << (instance.tags[@ec2_config[:aws_stages_tag]]  || '').ljust( column_widths[:stages]  ).yellow if stages_present
      status_output << (instance.tags[@ec2_config[:aws_roles_tag]]   || '').ljust( column_widths[:roles]   ).yellow if roles_present
      status_output << (instance.tags[@ec2_config[:aws_options_tag]] || '').ljust( column_widths[:options] ).yellow if options_present
      puts status_output.join("   ")
    end
  end

  def server_names
    desired_instances.map {|instance| instance.name}
  end

  def project_instances
    @instances.select {|instance| @ec2_config[:project_tags].include?(instance.tags[@ec2_config[:aws_project_tag]])}
  end

  def desired_instances(region = nil)
    instances = @ec2_config[:project_tags].empty? ? @instances : project_instances
    @ec2_config[:stage].to_s.empty? ? instances : get_instances_by_stage(instances)
  end

  def get_instances_by_role(role)
    desired_instances.select {|instance| instance.tags[@ec2_config[:aws_roles_tag]].split(%r{,\s*}).include?(role.to_s) rescue false}
  end

  def get_instances_by_stage(instances=@instances)
    instances.select {|instance| instance.tags[@ec2_config[:aws_stages_tag]].split(%r{,\s*}).include?(@ec2_config[:stage].to_s) rescue false}
  end

  def get_instances_by_region(roles, region)
    return unless region
    desired_instances.select {|instance| instance.availability_zone.match(region) && instance.tags[@ec2_config[:aws_roles_tag]].split(%r{,\s*}).include?(roles.to_s) rescue false}
  end

  def get_instance_by_name(name)
    desired_instances.select {|instance| instance.name == name}.first
  end

  def get_instance_by_dns(dns)
    desired_instances.select {|instance| instance.dns_name == dns}.first
  end

  def instance_health(load_balancer, instance)
    elb.describe_instance_health(load_balancer.id, instance.id).body['DescribeInstanceHealthResult']['InstanceStates'][0]['State']
  end

  def elb
    Fog::AWS::ELB.new({:region => @ec2_config[:aws_params][:region]}.merge!(security_credentials))
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

  def deregister_instance_from_elb_by_dns(server_dns)
    instance = get_instance_by_dns(server_dns)
    load_balancer = get_load_balancer_by_instance(instance.id)

    if load_balancer
      puts "[Capify-EC2] Removing instance from ELB '#{load_balancer.id}'..."

      result = elb.deregister_instances_from_load_balancer(instance.id, load_balancer.id)
      raise "Unable to remove instance from ELB '#{load_balancer.id}'..." unless result.status == 200

      return load_balancer
    end
    false
  end

  def reregister_instance_with_elb_by_dns(server_dns, load_balancer, timeout)
    instance = get_instance_by_dns(server_dns)

    sleep 10

    puts "[Capify-EC2] Re-registering instance with ELB '#{load_balancer.id}'..."
    result = elb.register_instances_with_load_balancer(instance.id, load_balancer.id)

    raise "Unable to re-register instance with ELB '#{load_balancer.id}'..." unless result.status == 200

    state = nil

    begin
      Timeout::timeout(timeout) do
        begin
          state = instance_health(load_balancer, instance)
          raise "Instance not ready" unless state == 'InService'
        rescue => e
          puts "[Capify-EC2] Unexpected response: #{e}..."
          sleep 1
          retry
        end
      end
    rescue Timeout::Error => e
    end
    state ? state == 'InService' : false
  end

  def instance_health_by_url(dns, port, path, expected_response, options = {})
    def response_matches_expected?(response, expected_response)
      if expected_response.kind_of?(Array)
        expected_response.any?{ |r| response_matches_expected?(response, r) }
      elsif expected_response.kind_of?(Regexp)
        (response =~ expected_response) != nil
      else
        response == expected_response
      end
    end

    protocol = options[:https] ? 'https://' : 'http://'
    uri = URI("#{protocol}#{dns}:#{port}#{path}")

    puts "[Capify-EC2] Checking '#{uri}' for the content '#{expected_response.inspect}'..."

    http = Net::HTTP.new(uri.host, uri.port)

    if uri.scheme == 'https'
     http.use_ssl = true
     http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    result = nil

    begin
      Timeout::timeout(options[:timeout]) do
        begin
          result = http.get(uri.path)
          raise "Server responded with '#{result.code}: #{result.body}', expected '#{expected_response}'" unless response_matches_expected?(result.body, expected_response)
        rescue => e
          puts "[Capify-EC2] Unexpected response: #{e}..."
          sleep 1
          retry
        end
      end
    rescue Timeout::Error => e
    end
    result ? response_matches_expected?(result.body, expected_response) : false
  end
end

def instance_dns_with_name_tag(dns)
  name_tag     = ''
  current_node = capify_ec2.desired_instances.select { |instance| instance.dns_name == dns }
  name_tag     = current_node.first.tags['Name'] unless current_node.empty?
  "#{dns} (#{name_tag})"
end

def format_rolling_deploy_results(all_servers, results)
  puts '[Capify-EC2]      None.' unless results.any?
  results.each {|server| puts "[Capify-EC2]      #{instance_dns_with_name_tag(server)} with #{all_servers[server].count >1 ? 'roles' : 'role'} '#{all_servers[server].join(', ')}'."}
end

class CapifyEC2RollingDeployError < Exception
  attr_reader :dns

  def initialize(msg, dns)
    super(msg)
    @dns = dns
  end
end
