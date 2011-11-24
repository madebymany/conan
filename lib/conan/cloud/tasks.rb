require "fileutils"
require "json"
require File.expand_path(File.join(File.dirname(__FILE__), 'aws/provision'))

namespace :aws do

  task :provision do
    aws_config = JSON.parse(File.read("config/aws.json"))[stage] || {}
    AWS::Provision.new(aws_config, stage).build_env
  end

  task :write_config do
     AWS::Provision.new.describe_env_to_json("config/servers.json")
  end
end

