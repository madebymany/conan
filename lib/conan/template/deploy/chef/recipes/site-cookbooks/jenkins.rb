execute "Add Jenkins key" do
	command "wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -"
end

execute "Add Jenkins repo to sources list" do
	command "echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list"
end

execute "Reload sources" do 
	command "apt-get update"
end

execute "Install Jenkins" do
	command "apt-get install jenkins"
end