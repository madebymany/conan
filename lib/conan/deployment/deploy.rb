require "json"
set :server_config, JSON.parse(File.read("config/servers.json"))[stage] || {}

roles = Hash.new{ |h,k| h[k] = [] }

server_config.each do |s, c|
  c["roles"].each do |r|
    roles[r.to_sym] << s
  end
end

roles.each do |r, ss|
  next unless [:app, :db].include?(r)
  ss.each_with_index do |s, i|
    role r, s, :primary => (i == 0)
  end
end

namespace :deploy do
  task :start, :roles => :app do; end
  task :stop,  :roles => :app do; end

  task :restart, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt"
  end
  after "deploy:restart", "deploy:cleanup"

  namespace :maintenance do
    task :start, :roles => :app do
      run "cp #{current_path}/public/maintenance.html #{current_path}/public/system/maintenance.html || echo"
    end

    task :stop, :roles => :app do
      run "rm -f #{current_path}/public/system/maintenance.html"
    end
  end

  task :link_shared, :roles => :app do
    shared_paths.each do |s|
      run "rm -f #{release_path}/#{s}"
      run "ln -nfs #{shared_path}/#{s} #{release_path}/#{s}"
    end
  end
  after "deploy:update_code", "deploy:link_shared"

  desc "Deploy and run migrations"
  task :default do
    maintenance.start
    update_code
    migrate
    symlink
    restart
    maintenance.stop
  end

  task :smoke_test do
    if File.exist?("test/deploy/smoke_test.rb")
      system "ruby test/deploy/smoke_test.rb #{stage}"
      unless $? == 0
        deploy.maintenance.start
        raise CommandError, "Smoke tests failed"
      end
    end
  end
  after "deploy", "deploy:smoke_test"
end
