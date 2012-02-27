require "fileutils"
require "json"

namespace :aws do

  task :provision do
    aws_config = JSON.parse(File.read("config/aws.json"))[stage] || {}
    AWS::Provision.new(stage, aws_config, application).build_env
  end

  task :write_config do
     server_config = AWS::Provision.new.describe_env
     File.open("config/servers.json", "w") do |io|
       io << JSON.pretty_generate(server_config)
     end
  end

  desc "Allows ssh to instance by name. cap ssh <NAME>"
  task :ssh do
    server = variables[:logger].instance_variable_get("@options")[:actions][2]
    instance = AWS::Provision.new(stage).find_server_by_name(server)
    unless instance.nil?
      port = ssh_options[:port] || 22
      command = "ssh -p #{port} ubuntu@#{instance.dns_name}"
      puts "Running `#{command}`"
      exec(command)
    else
      puts "Server #{server} not found"
    end
  end
  
  desc "create autoscale setup from config/autoscale.json"
  task :create_autoscale do
    autoscale_config = JSON.parse(File.read("config/autoscale.json"))[stage] || {}
    AWS::Autoscale.new(stage, autoscale_config, application).configure_autoscale
  end

  desc "update autoscale from config/autoscale.json after a deployment"
  task :update_autoscale do
    autoscale_config = JSON.parse(File.read("config/autoscale.json"))[stage] || {}
    AWS::Autoscale.new(stage, autoscale_config, application).update_autoscale
  end

end

