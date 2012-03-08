require 'rubygems'
# require 'fog/aws/models/compute/security_group'

module Fog
  module Compute
    class AWS
      class SecurityGroup < Fog::Model
        def authorize_ip_permission(port_range, options = {})
          requires :name

          permission = {
            'FromPort'    => port_range.min,
            'ToPort'      => port_range.max,
            'IpProtocol'  => options[:ip_protocol] || 'tcp'
          }

          if options[:group_name]
            grp_permitted = {'GroupName' => options[:group_name]}
            grp_permitted['UserId'] = options[:user_id] if options[:user_id]
            permission['Groups'] = [grp_permitted]
          else 
            ip_permitted = {'CidrIp' => "0.0.0.0/0"}
            if options[:cidr_ip]
              ip_permitted = {'CidrIp' => options[:cidr_ip]}
            end 
            permission['IpRanges'] = [ip_permitted]
          end

          connection.authorize_security_group_ingress(
            name,
            'IpPermissions' => [permission]
          )
        end
      end
    end
  end
end
