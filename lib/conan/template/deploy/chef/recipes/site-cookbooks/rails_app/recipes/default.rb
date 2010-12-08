gem_package "bundler" do
  version "1.0.2"
  action :install
end

node[:rails_app][:packages].each do |pkg_name|
  package pkg_name
end

user node[:rails_app][:user] do
  home node[:rails_app][:home]
end

directory "#{node[:rails_app][:home]}" do
  owner node[:rails_app][:user]
end

directory "#{node[:rails_app][:home]}/.ssh" do
  owner node[:rails_app][:user]
end

bash "copy_authorized_keys" do
  code <<-END
    cp /home/ubuntu/.ssh/authorized_keys #{node[:rails_app][:home]}/.ssh/authorized_keys
    chown #{node[:rails_app][:user]} #{node[:rails_app][:home]}/.ssh/authorized_keys
  END
end

template "/etc/apache2/sites-available/#{node[:rails_app][:name]}" do
  source "vhost.erb"
end

%w[
  releases
  shared
  shared/config
  shared/log
  shared/system
].each do |path|
  directory "#{node[:rails_app][:home]}/#{path}" do
    owner node[:rails_app][:user]
  end
end

if node[:rails_app][:database]
  template "#{node[:rails_app][:home]}/shared/config/database.yml" do
    source "database.yml.erb"
    owner node[:rails_app][:user]
  end
end

if node[:rails_app][:s3]
  template "#{node[:rails_app][:home]}/shared/config/amazon_s3.yml" do
    source "amazon_s3.yml.erb"
    owner node[:rails_app][:user]
  end
end

if node[:rails_app][:new_relic]
  template "#{node[:rails_app][:home]}/shared/config/newrelic.yml" do
    source "newrelic.yml.erb"
    owner node[:rails_app][:user]
  end
end

bash "placate_apache" do
  user node[:rails_app][:user]
  code %{ ln -s #{ node[:rails_app][:home] }/releases #{ node[:rails_app][:home] }/current }
  not_if { File.exist?("#{ node[:rails_app][:home] }/current") }
end

bash "enable_site" do
  code "a2ensite #{node[:rails_app][:name]}"
end

bash "reload_apache" do
  code "/etc/init.d/apache2 reload"
end
