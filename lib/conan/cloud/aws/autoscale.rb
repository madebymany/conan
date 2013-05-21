require 'fileutils'
require 'fog'
require 'json'

require_relative "./utils"

module AWS
  class Autoscale
    include Utils

    attr_accessor :autoscale_config, :stage, :application

    def initialize(stage = 'production', autoscale_config = {}, application = nil)
      @autoscale_config = autoscale_config
      @stage = stage
      @application = application
    end

    def create_ami_from_server(server_name, region, image_description = nil)
      image_name = "#{server_name}-image-#{Time.now.strftime('%Y%m%d%H%M')}" if image_name.nil?
      image_description = "Image of #{server_name} created at #{DateTime.now} by conan"
      server_to_image = find_server_by_name(server_name, region)

      raise "Server #{server_name} in #{region} does not exist" if server_to_image.nil?

      compute = Fog::Compute.new(:provider => :aws, :region => region)
      puts "Creating image #{image_name} from server #{server_name}"
      ami_request = compute.create_image(server_to_image.id, image_name, image_description)
      image_id = ami_request.body["imageId"]

      pending = true
      image = nil

      puts "Waiting for #{image_id} to become available"
      while pending 
        sleep 10
        image = compute.images.get(image_id)
        pending = image.state == "pending"
      end

      raise "Image creation failed" if image.state == 'failed'
      image_id

    end

    def create_launch_config(name, config = {})
      new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      region = new_conf[:region] || "us-east-1"

      compute = Fog::Compute.new(:provider => :aws, :region => region)

      params = {}
      params['KeyName'] = new_conf[:key_name] || compute.key_pairs.all.first.name

      if new_conf[:security_groups] and new_conf[:security_groups].size > 0
        params['SecurityGroups'] = new_conf[:security_groups].collect { |g| "#{stage}-#{g}" }
      else
        params['SecurityGroups'] = ["#{stage}-default"]
      end

      instance_type = new_conf.delete(:instance_type) || "m1.small"

      if new_conf[:server_to_image].nil?
        if new_conf[:image_id].nil?
          image_id = default_image_id(region, instance_type, new_conf[:root_device_type]) 
        else
          image_id = new_conf[:image_id]
        end
      else
        image_id = create_ami_from_server(new_conf[:server_to_image], region)
      end

      autoscale = Fog::AWS::AutoScaling.new(:region => region)

      #need to create new launchconfiugrations with unique names
      #because you can't modify them and you can't delete them if they are attached
      #to an autoscale group
      id = "#{ec2_name_tag(name)}-#{Time.now.strftime('%Y%m%d%H%M')}"

      puts "Creating Autoscale Launch Configuration #{id}"
      lc = autoscale.configurations.connection.create_launch_configuration(image_id, instance_type, id, params)

      new_conf[:autoscale_groups].each do |group_name|
        asg = autoscale.groups.get(group_name)
        puts "Setting Autoscale Group #{group_name} to use Launch Configration #{id}"
        asg.connection.update_auto_scaling_group(group_name, {"LaunchConfigurationName" => id})
      end unless new_conf[:autoscale_groups].nil?

    end

    def configure_autoscale
    end

    def update_autoscale
      autoscale_config.each do |type, resources|
         case type
         when "launch-config"
           resources.each do |name, conf|
             create_launch_config(name, conf)
           end
         end
      end
    end

    def launch_test_instances
      autoscale_config.each do |type, resources|
         case type
         when "launch-config"
           resources.each do |name, conf|
             start_test_server(name, conf)
           end
         end
      end
    end

    def start_test_server(name, config = {})
      new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      region = new_conf[:region] || "us-east-1"

      compute = Fog::Compute.new(:provider => :aws, :region => region)

      autoscale = Fog::AWS::AutoScaling.new(:region => region)
      asres = autoscale.describe_auto_scaling_groups({'AutoScalingGroupNames' => new_conf[:autoscale_groups]})
      lcname = ""
      #so aws APIs sometimes return a blank scaling group????? need to check if there is a LC
      asres.body["DescribeAutoScalingGroupsResult"]["AutoScalingGroups"].each do |asgroup|
        lcname = asgroup["LaunchConfigurationName"]
        break if !lcname.nil? && lcname.length > 0
      end

      lcres = autoscale.describe_launch_configurations({'LaunchConfigurationNames' => [lcname]})
      lc = lcres.body["DescribeLaunchConfigurationsResult"]["LaunchConfigurations"][0]

      compute = Fog::Compute.new(:provider => :aws, :region => region)
      server_params = {}
      server_params[:groups] = lc["SecurityGroups"]
      server_params[:key_name] = lc["KeyName"]
      server_params[:image_id] = lc["ImageId"]
      server_params[:monitoring] = false
      server_params[:flavor_id] = lc["InstanceType"]
      server_params[:root_device_type] = "ebs"
      server_params[:availability_zone] = default_availability_zone(region)


      puts "Creating test instance from image for launch configuration #{lcname}"
      server = compute.servers.create(server_params)
      server.wait_for { ready? }

      puts "Created server #{server.dns_name} for testing. Please delete manually"

    end

  end
end


