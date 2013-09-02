require 'rubygems'
require 'fog/aws/models/compute/server'

module Fog
  module Compute
    class AWS
      class Server
        def contact_point
          dns_name || public_ip_address || private_ip_address
        end
        
        def name
          tags["Name"] || ""
        end
      end
    end
  end
end