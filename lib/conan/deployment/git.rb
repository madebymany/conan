namespace :git do
  before "deploy:update_code", "git:tag_attempted_deploy" unless deploy_via == :copy
  task :tag_attempted_deploy do
    git_tag branch, "#{stage}.#{application}.last-deploy"
  end

  before "git:tag_attempted_deploy", "git:deploy_commits"  unless deploy_via == :copy
  task :deploy_commits do
    run_locally "git fetch origin --tags"
    logs = git_log("#{stage}.#{application}.last-successful-deploy", branch)
    puts "the following new commits for #{application} on #{stage} revision #{real_revision(branch)} will be deployed"
    puts logs
  end

  before "git:tag_successful_deploy", "git:deployed_commits"  unless deploy_via == :copy
  task :deployed_commits do
    logs = git_log("#{stage}.#{application}.last-successful-deploy", branch)
    puts "the following new commits for #{application} on #{stage} revision #{real_revision(branch)} were deployed"
    puts logs
  end

  task :tag_successful_deploy do
    git_tag branch, "#{stage}.#{application}.last-successful-deploy"
  end
  after "deploy:smoke_test", "git:tag_successful_deploy" unless deploy_via == :copy

  #this task exists only to migrate tags in applications
  task :migrate_tags do
    git_tag real_revision("#{stage}.last-deploy"), "#{stage}.#{application}.last-deploy"
    git_tag real_revision("#{stage}.last-successful-deploy"), "#{stage}.#{application}.last-successful-deploy"
  end
end
