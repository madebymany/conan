require "bundler/capistrano"
require "conan/deployment"

Capistrano::Configuration.instance(:must_exist).load do
  Conan::Deployment.define_tasks(self)
end
