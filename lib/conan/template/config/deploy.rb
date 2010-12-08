# Configuration

# Assume that we are deploying from the "origin" remote.
set :repository, `git remote -v | grep 'origin.*fetch' | awk '{print $2}'`.chomp

# Hopefully, your application name matches the repository name.
set :application, File.basename(repository, ".git")

# Files and directories to persist between deployments:
set :shared_paths, %w[
  config/database.yml
  log
]

# Deploy to staging if no branch is specified
set :stage, "staging" # default

# Your stages. The default assumes:
#
# * There is a staging and a production environment.
# * Staging is deployed from the master branch
# * Deployment to production is always made from the last branch successfully
#   deployed to staging.
#
task :staging do
  set :stage,  "staging"
  set :branch, "master"
end
task :production do
  set :stage,  "production"
  set :branch, "staging.last-successful-deploy"
end

# You probably don't need to edit these
default_run_options[:pty] = true
set :use_sudo,      false
set :deploy_via,    :remote_cache
set :keep_releases, 5
set :scm,           "git"
set :user,          "rails"
set :deploy_to,     "/mnt/#{application}"

# Let Conan take over
require "conan/capistrano"
