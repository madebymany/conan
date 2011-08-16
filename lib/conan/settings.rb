require "conan/version"

module Conan
  class Settings
    def initialize
      @settings = defaults
    end

    def []=(k, v)
      @settings[k] = v
    end

    def [](k)
      @settings[k]
    end

  private
    def defaults
      {
        "APPLICATION"         => application_from_git_remote,
        "COOKBOOK_REPOSITORY" => "git://github.com/madebymany/cookbooks.git",
        "COOKBOOK_BRANCH"     => "minimal",
        "VERSION"             => Conan::VERSION,
      }
    end

    def application_from_git_remote
      return nil unless File.exist?(".git")
      remote = File.basename(`git remote -v | grep -m1 origin | awk '{print $2}'`).strip
      return nil if remote.empty?
      remote[/([^:\/]+)\.git$/, 1]
    end
  end
end
