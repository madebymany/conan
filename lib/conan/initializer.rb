require "fileutils"

module Conan
  class Initializer
    TEMPLATE_PATH = File.expand_path("../template", __FILE__)

    def self.run(where=Dir.pwd)
      new(where).run
    end

    def initialize(where)
      @destination = File.expand_path(where)
    end

    def run
      copy_template
      add_gemfile
      add_gitignore
    end

  private
    def add_gemfile
      path = File.join(@destination, "Gemfile")
      lines =
        if File.exist?(path)
          File.read(path).split(/\n/)
        else
          []
        end

      group_line = "group :development do"
      gem_line   = "  gem \"conan\""

      if group_index = lines.index{ |l| l.include?(group_line) }
        lines.insert group_index+1, gem_line
      else
        lines << group_line
        lines << gem_line
        lines << "end"
      end

      File.open(path, "w") do |f|
        f << lines.join("\n")
      end
    end

    def add_gitignore
      File.open(".gitignore", "a") do |f|
        f.puts "/deploy/chef/dna/generated.json"
        f.puts "/deploy/chef/dna/aliases.json"
      end
    end

    def copy_template
      Dir.chdir(TEMPLATE_PATH) do
        Dir["**/*"].each do |source|
          target = File.join(@destination, source)
          if File.directory?(source)
            FileUtils.mkdir_p target
          else
            FileUtils.cp source, target
          end
        end
      end
    end
  end
end
