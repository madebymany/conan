username = `whoami`.strip

execute "set git email" do
  command "git config --global user.email 'jonathan@madebymany.com'"
  user username
end

execute "set git user" do
  command "git config --global user.name 'Jenkins CI Server'"
  user username
end