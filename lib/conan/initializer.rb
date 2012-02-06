require "fileutils"
require "rubygems"
require "bundler/setup"

module Conan
  class Initializer
    TEMPLATE_PATH = File.expand_path("../template", __FILE__)
    ShellCommandError = Class.new(RuntimeError)

    def self.run(where, settings)
      new(where, settings).run
    end

    def initialize(where, settings)
      @destination = File.expand_path(where)
      @settings = Conan::Settings.new(settings)
    end

    def run
      copy_template
      add_gitignore
      add_git_submodule
    end

  private
    def add_gitignore
      gitignore = ".gitignore"
      File.open(".gitignore", "a") do |f|
        f.puts
        f.puts "/deploy/chef/dna/generated.json"
        f.puts "/deploy/chef/dna/aliases.json"
      end
    end

    def add_git_submodule
      return unless File.directory?(".git")
      sh "git submodule add #{@settings["COOKBOOK_REPOSITORY"]} deploy/chef/recipes/cookbooks #{@settings["COOKBOOK_BRANCH"]} >/dev/null 2>&1"
    end

    def copy_template
      Dir.chdir(TEMPLATE_PATH) do
        Dir["**/*"].each do |source|
          target = File.join(@destination, source)
          if File.directory?(source)
            FileUtils.mkdir_p target
          else
            content = File.read(source)
            content.gsub!(/\{\{([A-Z_]+)\}\}/){ @settings[$1] || "TODO" }
            File.open(target, "w") do |f|
              f << content
            end
            File.chmod(File.stat(source).mode, target)
          end
        end
      end
    end

    def sh(command)
      system command or raise ShellCommandError, command
    end
  end
end
