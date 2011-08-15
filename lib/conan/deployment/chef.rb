require "fileutils"

namespace :chef do
  task :update_aliases do
    require "json"

    cache_path = "tmp/cache/server_internal_addresses.json"

    cache =
      if File.exist?(cache_path)
        JSON.parse(File.read(cache_path))
      else
        {}
      end

    aliases = {}
    server_config.each do |host, config|
      cache[host] ||= `ssh #{host} ifconfig`[/inet addr:(10\.\d+\.\d+\.\d+)/, 1]
      aliases[config["alias"]] = cache[host]
    end

    FileUtils.mkdir_p File.dirname(cache_path)
    File.open(cache_path, "w") do |io|
      io << JSON.dump(cache)
    end

    File.open("deploy/chef/dna/aliases.json", "w") do |io|
      io << JSON.dump({"hosts" => aliases})
    end
  end

  before "chef:rsync", "chef:update_aliases"
  task :rsync do
    require "json"
    require "conan/smart_hash_merge"

    ssh_options = {
      'BatchMode'             => 'yes',
      'CheckHostIP'           => 'no',
      'ForwardAgent'          => 'yes',
      'StrictHostKeyChecking' => 'no',
      'UserKnownHostsFile'    => '/dev/null'
    }.map{|k, v| "-o #{k}=#{v}"}.join(' ')

    server_config.each do |host, config|
      dna = {}
      (["base", "aliases"] + config["roles"]).each do |role|
        path = "deploy/chef/dna/#{role}.json"
        next unless File.exist?(path)
        dna = Conan::SmartHashMerge.merge(dna, JSON.parse(File.read(path)))
      end

      File.open("deploy/chef/dna/generated.json", "w") do |io|
        io << JSON.dump(dna)
      end

      system "rsync -Caz --rsync-path='sudo rsync' --delete --exclude .git --exclude '.*.swp' --rsh='ssh -l ubuntu #{ssh_options}' deploy/chef/ #{host}:/etc/chef"
    end
  end

  before "chef:bootstrap", "chef:rsync"
  task :bootstrap do
    with_user "ubuntu" do
      run "sudo /etc/chef/recipes/cookbooks/bootstrap/bootstrap.sh"
    end
  end

  before "chef:update", "chef:bootstrap"
  task "update" do
    with_user "ubuntu" do
      run "sudo chef-solo -j /etc/chef/dna/generated.json"
    end
  end
end

desc "Install and configure server(s)"
task "configure" do
  chef.update
end
