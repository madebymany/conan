require 'rubygems'
require 'fog/aws/requests/auto_scaling/create_launch_configuration'

module Fog
  module AWS
      class AutoScaling

        class Real

          def create_launch_configuration(image_id, instance_type, launch_configuration_name, options = {})
            if block_device_mappings = options.delete('BlockDeviceMappings')
              block_device_mappings.each_with_index do |mapping, i|
                for key, value in mapping
                  options.merge!({ format("BlockDeviceMappings.member.%d.#{key}", i+1) => value })
                end
              end
            end
            if security_groups = options.delete('SecurityGroups')
              options.merge!(Fog::AWS.indexed_param('SecurityGroup.member', [*security_groups]))
            end
            if options['UserData']
              options['UserData'] = Base64.encode64(options['UserData'])
            end

            request({
              'Action'                  => 'CreateLaunchConfiguration',
              'ImageId'                 => image_id,
              'InstanceType'            => instance_type,
              'LaunchConfigurationName' => launch_configuration_name,
              :parser                   => Fog::Parsers::AWS::AutoScaling::Basic.new
            }.merge!(options))
          end

      end
    end
  end
end
