require 'rubygems'
require 'fog/aws/models/compute/server'

module Fog
  module Compute
    class AWS
      class Server
        def contact_point
          dns_name || public_ip_address || private_ip_address
        end
        
        def method_missing(method_sym, *arguments, &block)
          tags.each do |key, value|
            tag = key.downcase.gsub(/\W/, '')
            return value if method_sym.to_s == tag
          end if tags
          super
        end
        
        def respond_to?(method_sym, include_private = false)
          tags.each do |key, value|
            tag = key.downcase.gsub(/\W/, '')
            return true if method_sym.to_s == tag
          end if tags
          super
        end
      end
    end
  end
end