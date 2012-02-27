require "bundler/capistrano"
require "conan/deployment"
require "conan/cloud/aws/provision"
require "conan/cloud/aws/autoscale"

Capistrano::Configuration.instance(:must_exist).load do
  Conan::Deployment.define_tasks(self)
end
