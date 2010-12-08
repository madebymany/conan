node[:railsapp][:packages].each do |pkg_name|
  package pkg_name
end

node[:railsapp][:gems].each do |gem_name, gem_version|
  gem_package gem_name do
    version gem_version
    action :install
  end
end

user node[:railsapp][:user] do
  home node[:railsapp][:home]
end

directory "#{node[:railsapp][:home]}" do
  owner node[:railsapp][:user]
end

directory "#{node[:railsapp][:home]}/.ssh" do
  owner node[:railsapp][:user]
end

bash "copy_authorized_keys" do
  code <<-END
    cp /root/.ssh/authorized_keys #{node[:railsapp][:home]}/.ssh/authorized_keys
    chown #{node[:railsapp][:user] #{node[:railsapp][:home]}/.ssh/authorized_keys
  END
end

template "/etc/apache2/sites-available/#{node[:railsapp][:name]}" do
  source "vhost.erb"
end

%w[
  releases
  shared
  shared/log
  shared/system
].each do |path|
  directory "#{node[:railsapp][:home]}/#{path}" do
    owner node[:railsapp][:user]
  end
end

if node[:railsapp][:database]
  template "#{node[:railsapp][:home]}/shared/config/database.yml" do
    source "database.yml.erb"
    owner node[:railsapp][:user]
  end
end

if node[:railsapp][:s3]
  template "#{node[:railsapp][:home]}/shared/config/amazon_s3.yml" do
    source "amazon_s3.yml.erb"
    owner node[:railsapp][:user]
  end
end

if node[:railsapp][:new_relic]
  template "#{node[:railsapp][:home]}/shared/config/newrelic.yml" do
    source "newrelic.yml.erb"
    owner node[:railsapp][:user]
  end
end

bash "placate_apache" do
  user node[:railsapp][:user]
  code %{ ln -s #{ node[:railsapp][:home] }/releases #{ node[:railsapp][:home] }/current }
  not_if { File.exist?("#{ node[:railsapp][:home] }/current") }
end

bash "enable_site" do
  code "a2ensite #{node[:railsapp][:name]}"
end

bash "reload_apache" do
  code "/etc/init.d/apache2 reload"
end
