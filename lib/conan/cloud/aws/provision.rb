require "fileutils"
require "fog"
require "json"

require_relative "./utils"
require_relative "./security_group"

module AWS

  class Provision
  include Utils

    attr_accessor :aws_config, :stage, :application

    def initialize(stage = 'production', aws_config = {}, application = nil)
      @aws_config = aws_config
      @stage = stage
      @application = application
    end

    def describe_env(filter_role = nil)
      server_config = {}
      servers = []
      all_regions.each do |region|
        compute = Fog::Compute.new(:provider => :aws, :region => region)
        compute.servers.all.each { |s| servers << s if s.state == 'running' }
      end
      stages = servers.map {|s| s.tags["stage"] }.uniq

      stages.each do | st|
        server_config[st] = {}
        servers.each do |server|
          if server.tags["stage"] == st && !server.tags["roles"].nil?
            config = {}
            config["roles"] = server.tags["roles"].split /,\s*|:/
            config["alias"] = server.tags["name"]
            if filter_role.nil? || config["roles"].include?(filter_role)
              server_config[st][server.dns_name] = config
            end
          end 
        end
      end
      server_config

    end
    
    def build_env

      raise "Settings file at ~/.fog not found" unless File.exists?("#{ENV['HOME']}/.fog")

      #first key_pairs
      key_pairs = aws_config["key_pairs"]

      key_pairs.each do |name, conf|
        create_key_pair(name, conf)
      end unless key_pairs.nil?

      security_groups = aws_config["security"]

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

      aws_config.each do |type, resources|
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

      sg_name = ec2_name_tag(name)

      sg = compute.security_groups.get(sg_name)
      if sg.nil?
        puts "Creating EC2 Secruity Group #{sg_name}"
        sg = compute.security_groups.create(:name => sg_name, :description => "#{name} Security Group for #{stage}")
        new_conf[:ingress].each do |ingress|
          ingress = ingress.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo} 
          port = ingress.delete(:port)
          if ingress[:group_name]
            ingress[:group_name] = ec2_name_tag(ingress[:group_name]) 
            sg.authorize_ip_permission(Range.new(port.to_i,port.to_i),ingress)
          else
            sg.authorize_port_range(Range.new(port.to_i,port.to_i),ingress)
          end
        end unless new_conf[:ingress].nil?
      else
        puts "EC2 Security Group #{sg_name} already exists. Skipping"
      end

    end

    def create_rds_security_group(name, config = {})
      unless Fog.mocking?
        new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
        region = new_conf[:region] || "us-east-1"
        rds = Fog::AWS::RDS.new(:region => region)

        rdssg_name = rds_name_tag(name)

        rdssg = rds.security_groups.get(rdssg_name)

        if rdssg.nil?
          puts "Creating RDS Security Group #{rdssg_name}"
          rdssg = rds.security_groups.create(:id => rdssg_name, :description => "#{name} DB Security Group For #{stage}")
          new_conf[:ec2_security_groups].each do |ec2_group|
            rdssg.authorize_ec2_security_group("#{stage}-#{ec2_group}")
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

        cache_sg_name = elasticache_name_tag(name)

        sg_exists = false
        body = elasticache.describe_cache_security_groups.body
        sg_exists = body['CacheSecurityGroups'].any? do |group|
          group['CacheSecurityGroupName'] == cache_sg_name
        end

        unless sg_exists
          puts "Creating Elasticache Security Group #{cache_sg_name}"
          body = elasticache.create_cache_security_group(cache_sg_name, "#{cache_sg_name} ElastiCache Security Group for #{stage}").body
          new_conf[:ec2_security_groups].each do |ec2_group|
            compute = Fog::Compute.new(:provider => :aws, :region => region)
            sg_name = ec2_name_tag(ec2_group)
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

      new_conf['LocationConstraint'] = new_conf.delete(:location_constraint) if new_conf[:location_constraint]

      begin
        bucket = storage.get_bucket(name)
        puts "S3 Bucket #{name} already exists. Skipping"
      rescue Excon::Errors::NotFound
        puts "Creating S3 Bucket #{name}"
        storage.put_bucket(name, new_conf)

        acl = new_conf[:acl] || 'public-read'

        storage.put_bucket_acl(name, acl)
      end
    end

    def create_elb(name, config = {})
      new_conf = config.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      region = new_conf[:region] || "us-east-1"

      elb = Fog::AWS::ELB.new(:region => region)

      zones = new_conf[:availability_zones] || all_availability_zones(region)

      elb_name = ec2_name_tag(name)

      lb = elb.load_balancers.get(elb_name)
      if lb.nil?
        puts "Creating Elastic Load Balancer #{elb_name}"
      
        listeners = [];
        
        if new_conf[:listeners].nil?
          list = Fog::AWS[:elb].listeners.new()
          listeners << { 'Listener' => list.to_params, 'PolicyNames' => [] }
        else 
          new_conf[:listeners].each do |listener|
            listener = listener.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
            list = Fog::AWS[:elb].listeners.new(listener)
            listeners << { 'Listener' => list.to_params, 'PolicyNames' => [] }
          end
        end
      
        lb = elb.load_balancers.create(:id => elb_name, :availability_zones => zones, 'ListenerDescriptions' => listeners)

        compute = Fog::Compute.new(:provider => :aws, :region => region)

        new_conf[:ingress_for].each do |ingress|
          ingress = ingress.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo} 
          port = ingress.delete(:port)
          sg_name = ec2_name_tag(ingress[:group_name]) 
          sg = compute.security_groups.get(sg_name)
          lbsgparams = {:group_name => lb.source_group['GroupName'], :user_id => lb.source_group['OwnerAlias']}
          sg.authorize_ip_permission(Range.new(port.to_i,port.to_i),lbsgparams)
        end unless new_conf[:ingress_for].nil?

        inst_servers = new_conf[:servers].map { |s| ec2_name_tag(s) } unless new_conf[:servers].nil?

        list_stage_servers(region).each do |server|
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

      #need to parse all servers to see if this one exists
      server = find_server_by_name(name, region)

      #need to bork if no name in config file
      ec2_name = ec2_name_tag(name)

      unless server
        puts "Creating EC2 Server named #{ec2_name}"
        tags[:name] = ec2_name
        tags[:Name] = ec2_name
        tags[:stage] = stage

        if new_conf[:roles] 
          new_conf[:roles] << stage unless new_conf[:roles].include? stage 
          tags[:roles] = new_conf[:roles].join(', ')
        else
          tags[:roles] = "app, db, #{stage}"
        end

        params[:tags] = tags

        if new_conf[:groups] and new_conf[:groups].size > 0
          params[:groups] = new_conf[:groups].collect { |g| "#{stage}-#{g}" }
        else
          params[:groups] = ["#{stage}-default"]
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

        params[:id] = ec2_name_tag(name)

        params.delete(:availability_zone) if params[:multi_az]

        if new_conf[:db_security_groups] and new_conf[:db_security_groups].size > 0
          params[:security_group_names] = new_conf[:db_security_groups].collect { |g| rds_name_tag(g) }
        else
          params[:security_group_names] = [rds_name_tag('default')]
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

        default_params = { :node_type => "cache.m1.large", 
                           :num_nodes => 1,
                           :port => 11211, 
                           :preferred_availability_zone => default_availability_zone(region) 
                         }

        params = default_params.merge(new_conf)

        if new_conf[:security_groups] and new_conf[:security_groups].size > 0
          params[:security_group_names] = new_conf[:security_groups].collect { |g| elasticache_name_tag(g)  }
        else
          params[:security_group_names] = [elasticache_name_tag('default')]
        end

        cluster_name = ec2_name_tag(name) 

        cl = elasticache.clusters.get(cluster_name)

        unless cl
          puts "Creating ElastiCache cluster #{cluster_name}"
          params[:id] = cluster_name
          cl = elasticache.clusters.new(params)
          cl.save
        else
          puts "Elasticache cluster #{cluster_name} already exists. Skipping"
        end

      end
    end

  end
end

