require "conan/capistrano"

# Configuration

# What is the application called?
set :application, "yourappname" # TODO

# Hopefully, your application name matches the repository name. If, not, change
# this:
set :repository, "git@github.com:madebymany/#{application}"

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
add_stage :staging => "master"
add_stage :production => "staging.last-successful-deploy"
