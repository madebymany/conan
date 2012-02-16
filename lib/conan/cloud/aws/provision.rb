require "fileutils"
require "fog"
require "json"

module AWS
  class Provision

    def initialize(aws_config = {}, stage = 'production')
      @aws_config = aws_config
      @stage = stage
    end

    def describe_env_to_json(file_path)
      servers_json = {}
      servers = []
      ["us-east-1", "us-west-1", "eu-west-1", "ap-southeast-1", "ap-northeast-1"].each do |region|
        compute = Fog::Compute.new(:provider => :aws, :region => region)
        compute.servers.all.each { |s| servers << s if s.state == 'running' }
      end
      stages = servers.map {|s| s.tags["stage"] }.uniq

      stages.each do | stage|
        servers_json[stage] = {}
        servers.each do |server|
          if server.tags["stage"] == stage
            server_json = {}
            server_json[:roles] = server.tags["roles"].split(", ") unless server.tags["roles"].nil?
            server_json[:alias] = server.tags["name"]
            servers_json[stage][server.dns_name] = server_json
          end 
        end
      end

      File.open(file_path, "w") do |io|
        io << JSON.pretty_generate(servers_json)
      end
    end
    
    def build_env()

      #we need to check the existance of ~/.fog

      #first key_pairs
      key_pairs = @aws_config["key_pairs"]

      key_pairs.each do |name, conf|
        create_key_pair(name, conf)
      end unless key_pairs.nil?

      security_groups = @aws_config["security"]

      if security_groups.nil? or security_groups.size == 0
        create_default_security_groups()
      else
        security_groups["ec2"].each do |name, conf|
          create_ec2_security_group(name, conf)
        end unless security_groups["ec2"].nil?

        security_groups["rds"].each do |name, conf|
          create_rds_security_group(name, conf)
        end unless security_groups["rds"].nil?

        security_groups["elasticache"].each do |name, conf|
          create_elasticache_security_group(name, conf)
        end unless security_groups["elasticache"].nil?
      end

      @aws_config.each do |type, resources|
         case type
         when "ec2"
           resources.each do |name, conf|
             create_ec2_server(name, conf)
           end
         when "rds"
           resources.each do |name, conf|
             create_rds_server(name, conf)
           end
         when "s3"
           resources.each do |name, conf|
             create_s3_bucket(name, conf)
           end
         when "elb"
           resources.each do |name,conf|
             create_elb(name, conf)
           end
         end
         when "elasticache"
           resources.each do |name,conf|
             create_elasticache_cluster(name,conf)
           end
         end
      end
    end

    def create_key_pair(name, config = {})
      new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo} 
      region = new_conf[:region] || "us-east-1"
      compute = Fog::Compute.new(:provider => :aws, :region => region)

      kp = compute.key_pairs.get(name)
      if kp.nil?
        #no key pair create and write it out
        puts "Creating key-pair #{name}"
        kp = compute.key_pairs.create(:name => name)

        puts "Writing key into your .ssh directory and adding it to ssh agent"
        File.open("#{ENV['HOME']}/.ssh/#{kp.name}.pem", "w") do |io|
          io << kp.private_key 
        end
        system("chmod 600 #{ENV['HOME']}/.ssh/#{kp.name}.pem")
        system("ssh-add #{ENV['HOME']}/.ssh/#{kp.name}.pem")
      else
        puts "Key-pair #{name} already exists. Skipping"
      end
    end

    def create_default_security_groups()
      create_ec2_security_group('default', {:ports => ["22", "80"]})
      create_rds_security_group('default', {:ec2_security_groups => ["default"]})
    end

    def create_ec2_security_group(name, config = {})
      new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo} 
      region = new_conf[:region] || "us-east-1"

      compute = Fog::Compute.new(:provider => :aws, :region => region)

      sg_name = "#{@stage}-#{name}"

      sg = compute.security_groups.get(sg_name)
      if sg.nil?
        puts "Creating EC2 Secruity Group #{sg_name}"
        sg = compute.security_groups.create(:name => sg_name, :description => "#{name} Security Group for #{@stage}")
        new_conf[:ports].each do |port|
          sg.authorize_port_range(Range.new(port.to_i,port.to_i))
        end unless new_conf[:ports].nil?
      else
        puts "EC2 Security Group #{sg_name} already exists. Skipping"
      end

    end

    def create_rds_security_group(name, config = {})
      unless Fog.mocking?
        new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
        region = new_conf[:region] || "us-east-1"
        rds = Fog::AWS::RDS.new(:region => region)

        rdssg_name = "#{@stage}-db-#{name}"

        rdssg = rds.security_groups.get(rdssg_name)

        if rdssg.nil?
          puts "Creating RDS Security Group #{rdssg_name}"
          rdssg = rds.security_groups.create(:id => rdssg_name, :description => "#{name} DB Security Group For #{@stage}")
          new_conf[:ec2_security_groups].each do |ec2_group|
            rdssg.authorize_ec2_security_group("#{@stage}-#{ec2_group}")
          end
        else
          puts "RDS Security Group #{rdssg_name} already exists. Skipping"
        end

      end
    end

    def create_elasticache_security_group(name, config = {})
      unless Fog.mocking?
        new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
        region = new_conf[:region] || "us-east-1"
        elasticache = Fog::AWS::Elasticache.new(:region => region)

        cache_sg_name = "#{@stage}-elasticache-#{name}"

        sg_exists = false
        body = elasticache.describe_cache_security_groups.body
        body['CacheSecurityGroups'].any? do |group|
          group['CacheSecurityGroupName'] == cache_sg_name
        end

        unless sg_exists
          puts "Creating Elasticache Security Group #{cache_sg_name}"
          body = AWS[:elasticache].create_cache_security_group(cache_sg_name, "#{cache_sg_name} ElastiCache Security Group for #{@stage}").body
          new_conf[:ec2_security_groups].each do |ec2_group|
            compute = Fog::Compute.new(:provider => :aws, :region => region)
            sg_name = "#{@stage}-#{ec2_group}"
            sg = compute.security_groups.get(sg_name)
            body = elasticache.authorize_cache_security_group_ingress(
              cache_sg_name, sg.name, sg.owner_id).body
          end
        else
          puts "Elasticache Security Group #{cache_sg_name} already exists. Skipping"
        end

      end
    end

    def create_s3_bucket(name, config = {})
      new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      region = new_conf[:region] || "us-east-1"

      storage = Fog::Storage.new(:provider => :aws, :region => region)

      begin
        bucket = storage.get_bucket(name)
        puts "S3 Bucket #{name} already exists. Skipping"
      rescue Excon::Errors::NotFound
        puts "Creating S3 Bucket #{name}"
        storage.put_bucket(name)

        acl = new_conf[:acl] || 'public-read'

        storage.put_bucket_acl(name, acl)
      end
    end

    def create_elb(name, config = {})
      new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      region = new_conf[:region] || "us-east-1"

      elb = Fog::AWS::ELB.new(:region => region)

      zones = new_conf[:availability_zones] || all_availability_zones(region)

      elb_name = "#{@stage}-#{name}"

      lb = elb.load_balancers.get(elb_name)
      if lb.nil?
        puts "Creating Elastic Load Balancer #{elb_name}"
      
        lb = elb.load_balancers.create(:id => elb_name, :availability_zones => zones)
      
        #need to do listeners but for now stick with the default
      
        compute = Fog::Compute.new(:provider => :aws, :region => region)

        inst_servers = new_conf[:servers].map { |s| "#{@stage}-#{s}" } unless new_conf[:servers].nil?

        compute.servers.all.each do |server|
          #the mocking seems wrong
          unless Fog.mocking?
            name = server.tags["name"]
            lb.register_instances(server.id) if (inst_servers.nil? or inst_servers.include?(name))
          end
        end
      else
        puts "Elastic Load Balancer #{elb_name} already exists. Skipping"
      end

    end

    def create_ec2_server(name, config = {})
      new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      region = new_conf[:region] || "us-east-1"

      compute = Fog::Compute.new(:provider => :aws, :region => region)

      default_key_name = compute.key_pairs.all.first.name

      default_params = { :availability_zone => default_availability_zone(region), 
                         :flavor_id => "m1.small", 
                         :monitoring => true,
                         :key_name => default_key_name, 
                         :root_device_type => "instance-store" 
                       }

      params = default_params.merge(new_conf)
      params[:image_id] = default_image_id(region, params[:flavor_id], params[:root_device_type]) if params[:image_id].nil?

      tags  = {}

      #need to bork if no name in config file
      ec2_name = "#{@stage}-#{name}"

      #need to parse all servers to see if this one exists
      servers = compute.servers.all
      server_exists = false
      servers.each { |server| server_exists = true if server.tags["name"] == ec2_name and server.state == 'running' }

      unless server_exists
        puts "Creating EC2 Server named #{ec2_name}"
        tags[:name] = ec2_name
        tags[:stage] = @stage

        if new_conf[:roles] 
          new_conf[:roles] << @stage unless new_conf[:roles].include? @stage 
          tags[:roles] = new_conf[:roles].join(', ')
        else
          tags[:roles] = "app, db, #{@stage}"
        end

        params[:tags] = tags

        if new_conf[:groups] and new_conf[:groups].size > 0
          params[:groups] = new_conf[:groups].collect { |g| "#{@stage}-#{g}" }
        else
          params[:groups] = ["#{@stage}-default"]
        end

        server = compute.servers.create(params)
        server.wait_for { ready? } 
      else
        puts "EC2 Server named #{ec2_name} already exists. Skipping"
      end

    end

    def create_rds_server(name, config = {})
      unless Fog.mocking?
        new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
        region = new_conf[:region] || "us-east-1"
        rds = Fog::AWS::RDS.new(:region => region)
        default_params = { :allocated_storage => 20, 
                           :engine => 'mysql',
                           :master_username => 'root', 
                           :password => 'password',
                           :backup_retention_period => 8, 
                           :multi_az => false,
                           :db_name =>"production", 
                           :availability_zone => default_availability_zone(region), 
                           :flavor_id => 'db.m1.small'
                         }
        params = default_params.merge(new_conf)

        params[:id] = "#{@stage}-#{name}"

        if new_conf[:db_security_groups] and new_conf[:db_security_groups].size > 0
          params[:db_security_groups] = new_conf[:db_security_groups].collect { |g| "#{@stage}-db-#{g}" }
        else
          params[:db_security_groups] = ["#{@stage}-db-default"]
        end

        server = rds.servers.get(params[:id])

        if server.nil?
          puts "Creating RDS Server #{params[:id]}"
          server = rds.servers.create(params)
        else
          puts "RDS Server #{params[:id]} already exists. Skipping"
        end
      else
        puts "Fog is mocking. Can't test with RDS Servers. Skipping"
      end
    end

    def create_elasticache_cluster(name, config = {})
      unless Fog.mocking?
        new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
        region = new_conf[:region] || "us-east-1"

        elasticache = Fog::AWS::Elasticache.new(:region => region)

        default_params = { :node_type=> "cache.m1.large", 
                           :nodes => 1,
                           :port=> 11211, 
                           :availability_zone => default_availability_zone(region) 
                         }

        params = default_params.merge(new_conf)

        if new_conf[:security_groups] and new_conf[:security_groups].size > 0
          params[:security_groups] = new_conf[:security_groups].collect { |g| "#{@stage}-elasticache-#{g}" }
        else
          params[:security_groups] = ["#{@stage}-elasticache-default"]
        end

        cluster_name = "#{@stage}-#{name}"

        body = AWS[:elasticache].describe_cache_clusters.body
        exists = body['CacheClusters'].any? do |cluster|
          cluster['CacheClusterId'] == cluster_name
        end

        unless exists
          puts "Creating ElastiCache cluster #{cluster_name}"
          body = AWS[:elasticache].create_cache_cluster(cluster_name, params).body
        else
          puts "Elasticache cluster #{cluster_name} already exists. Skipping"
        end

      end
    end

    private

    def default_availability_zone(region)
      #using availability zone b by default as a is often unavailable in us-east-1
      "#{region}b"
    end

    def all_availability_zones(region)
      case region
      when "us-east-1"
        #not using availability zone us-east-1a as it often fails
        ["us-east-1b", "us-east-1c"]
      when "us-west-1"
        ["us-west-1a", "us-west-1b", "us-west-1c"]
      when "eu-west-1"
        ["eu-west-1a", "eu-west-1b"]
      when "ap-northeast-1"
        ["ap-northeast-1a", "ap-northeast-1a"]
      when "ap-southeast-1"
        ["ap-southeast-1a", "ap-southeast-1b"]
      end
    end

    def default_image_id(region, flavor_id, root_device_type)
      arch = ["m1.small", "t1.micro", "c1.medium"].include?(flavor_id) ? "32-bit" : "64-bit"

      defaults = JSON.parse(File.read(File.expand_path(File.join(File.dirname(__FILE__), 'default_amis.json'))))
      
      region_defaults = defaults["ubuntu 10.04"][region]
      raise "Invalid Region" if region_defaults.nil?
      default_ami = region_defaults[arch][root_device_type]

      raise "Default AMI not found for #{region} #{flavor_id} #{root_device_type}" if default_ami.nil?
      default_ami

    end
  end
end

