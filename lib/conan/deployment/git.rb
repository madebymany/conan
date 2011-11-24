namespace :git do
  before "deploy:update_code", "git:tag_attempted_deploy" unless deploy_via == :copy
  task :tag_attempted_deploy do
    git_tag branch, "#{stage}.last-deploy"
  end

  task :tag_successful_deploy do
    git_tag branch, "#{stage}.last-successful-deploy"
  end
  after "deploy:smoke_test", "git:tag_successful_deploy" unless deploy_via == :copy
end
