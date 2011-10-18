require 'rubygems'
require 'fog'
require 'fog/aws/models/compute/server'

module AWSServerExtension
  def case_insensitive_tag(key)
    tags[key] || tags[key.downcase]
  end
  
  def name
    case_insensitive_tag("Name").split('-').reject {|portion| portion.include?(".")}.join("-")
  end

  # module ClassMethods
  #   def define_methods_from_tags
  #     tags.each do |tag, value|
  #       tag.downcase!
  #       define_method tag do
  #         if tag =~ /.*s/
  #           value.split(',').gsub(/\s/,'')
  #         else
  #           value
  #         end
  #       end
  #     end
  #   end
  # end
  # 
  # def self.included(base)
  #   base.extend(ClassMethods)
  #   base.define_methods_from_tags
  # end

  def roles
    role = case_insensitive_tag("Role")
    roles = role.nil? ? [] : [role]
    if (roles_tag = case_insensitive_tag("Roles"))
      roles += case_insensitive_tag("Roles").split(/\s*,\s*/)
    end
    roles
  end
  def options
    option = case_insensitive_tag("Option")
    options = option.nil? ? [] : [option]
    if (options_tag = case_insensitive_tag("Options"))
      options += case_insensitive_tag("Options").split(/\s*,\s*/)
    end
    options
  end
end

module Fog
  module Compute
    class Server
      include AWSServerExtension
    end
  end
end