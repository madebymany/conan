require "fileutils"
require "fog"
require "json"

module AWS
  module Utils

    def ec2_name_tag(server_name)
      "#{stage}-#{server_name}"
    end

    def rds_name_tag(server_name)
      "#{stage}-db-#{server_name}"
    end

    def elasticache_name_tag(server_name)
      "#{stage}-elasticache-#{server_name}"
    end

    def find_server_by_name(name, region = nil)
      regions_to_search = region.nil? ? all_regions : [region]
      found_servers = []
      regions_to_search.each do |r|
        compute = Fog::Compute.new(:provider => :aws, :region => r)
        servers = compute.servers.all
        found_servers = found_servers + servers.select { |server| server.tags["name"] == ec2_name_tag(name) and server.state == 'running' }
      end
      found_servers.empty? ? nil : found_servers[0]
    end
    
    def list_stage_servers(region = nil)
      regions_to_search = region.nil? ? all_regions : [region]
      found_servers = []
      regions_to_search.each do |r|
        compute = Fog::Compute.new(:provider => :aws, :region => r)
        servers = compute.servers.all
        found_servers = found_servers + servers.select { |server| server.tags["stage"] == stage and server.state == 'running' }
      end
      found_servers
    end

    def default_availability_zone(region)
      #using availability zone b by default as a is often unavailable in us-east-1
      "#{region}b"
    end

    def all_regions
      ['us-east-1', 'us-west-1', 'eu-west-1', 'ap-northeast-1', 'ap-southeast-1']
    end

    def all_availability_zones(region)
      case region
      when "us-east-1"
        #not using availability zone us-east-1a as it often fails
        ["us-east-1b", "us-east-1d"]
      when "us-west-1"
        ["us-west-1a", "us-west-1b", "us-west-1c"]
      when "eu-west-1"
        ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
      when "ap-northeast-1"
        ["ap-northeast-1a", "ap-northeast-1a"]
      when "ap-southeast-1"
        ["ap-southeast-1a", "ap-southeast-1b"]
      end
    end

    def default_image_id(region, flavor_id, root_device_type)
      #now default to 64 bit architecture as all flavors support 64 bit
      arch = "64-bit"

      defaults = JSON.parse(File.read(File.expand_path(File.join(File.dirname(__FILE__), 'default_amis.json'))))
      
      region_defaults = defaults["ubuntu 10.04"][region]
      raise "Invalid Region" if region_defaults.nil?
      default_ami = region_defaults[arch][root_device_type]

      raise "Default AMI not found for #{region} #{flavor_id} #{root_device_type}" if default_ami.nil?
      default_ami

    end
  end
end
