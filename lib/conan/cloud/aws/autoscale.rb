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
      default_key_name = compute.key_pairs.all.first.name

      default_params = { :instance_monitoring => true,
                         :instance_type => "m1.small",
                         :key_name => default_key_name
                       }

      params = default_params.merge(new_conf)

      if new_conf[:security_groups] and new_conf[:security_groups].size > 0
        params[:security_groups] = new_conf[:security_groups].collect { |g| "#{stage}-#{g}" }
      else
        params[:security_groups] = ["#{stage}-default"]
      end

      if params[:server_to_image].nil?
        params[:image_id] = default_image_id(region, params[:flavor_id], params[:root_device_type]) if params[:image_id].nil?
      else
        params[:image_id] = create_ami_from_server(params[:server_to_image], region)      end

      autoscale = Fog::AWS::AutoScaling.new(:region => region)

      #need to create new launchconfiugrations with unique names
      #because you can't modify them and you can't delete them if they are attached
      #to an autoscale group
      params[:id] = "#{ec2_name_tag(name)}-#{Time.now.strftime('%Y%m%d%H%M')}"

      puts "Creating Autoscale Launch Configuration #{params[:id]}"
      lc = autoscale.configurations.create(params)

      params[:autoscale_groups].each do |group_name|
        asg = autoscale.groups.get(group_name)
        "Setting Autoscale Group #{group_name} to use Launch Configration #{params[:id]}"
        asg.connection.update_auto_scaling_group(asg.id, {"LaunchConfigurationName" => params[:id]})
      end unless params[:autoscale_groups].nil?

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

  end
end


