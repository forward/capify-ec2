require 'rubygems'
require 'fog/aws/models/compute/server'

module Fog
  module Compute
    class AWS
      class Server
        def method_missing(method_sym, *arguments, &block)
          tags.each do |key, value|
            tag = key.downcase.gsub(/\W/, '').chomp('s')
            return value if method_sym.to_s == tag
          end
          super
        end
        
        def respond_to?(method_sym, include_private = false)
          tags.each do |key, value|
            tag = key.downcase.gsub(/\W/, '').chomp('s')
            return true if method_sym.to_s == tag
          end
          super
        end
      end
    end
  end
end