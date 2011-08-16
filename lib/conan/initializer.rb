require "fileutils"

module Conan
  class Initializer
    TEMPLATE_PATH = File.expand_path("../template", __FILE__)
    ShellCommandError = Class.new(RuntimeError)

    def self.run(where=Dir.pwd)
      new(where).run
    end

    def initialize(where)
      @destination = File.expand_path(where)
    end

    def run
      copy_template
      add_gitignore
      add_git_submodule
    end

  private
    def git_repository_name
      return "TODO" unless File.exist?(".git")
      remote = File.basename(`git remote -v | grep -m1 origin | awk '{print $2}'`).strip
      return "TODO" if remote.empty?
      remote[/([^:\/]+)\.git$/, 1]
    end

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
      sh "git submodule add git://github.com/madebymany/cookbooks.git deploy/chef/recipes/cookbooks >/dev/null 2>&1"
    end

    def copy_template
      interpolations = [["{{APPLICATION}}", git_repository_name]]

      Dir.chdir(TEMPLATE_PATH) do
        Dir["**/*"].each do |source|
          target = File.join(@destination, source)
          if File.directory?(source)
            FileUtils.mkdir_p target
          else
            content = File.read(source)
            interpolations.each do |interpolation|
              content.gsub! *interpolation
            end
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
