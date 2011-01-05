module Conan
  class Deployment
    module Helpers
      def with_user(new_user, &blk)
        old_user = user
        return if old_user == new_user
        set :user, new_user
        close_sessions
        yield
        set :user, old_user
        close_sessions
      end

      def close_sessions
        sessions.values.each { |session| session.close }
        sessions.clear
      end

      def rake(command, options={})
        path = options[:path] || current_path
        run "cd #{path}; rake #{command} RAILS_ENV=#{rails_env}"
      end

      def git_tag(source, dest)
        system "git fetch origin --tags"
        sha1 = `git rev-parse "#{source}"`
        system %{git update-ref "refs/tags/#{dest}" #{sha1}}
        system %{git push -f origin tag #{dest}}
      end

      def add_role(*roles)
        roles = Hash.new{ |h,k| h[k] = [] }

        server_config.each do |s, c|
          c["roles"].each do |r|
            roles[r.to_sym] << s
          end
        end

        roles.each do |r, ss|
          next unless roles.include?(r)
          ss.each_with_index do |s, i|
            role r, s, :primary => (i == 0)
          end
        end
      end
    end

    class <<self
      def define_tasks(context)
        load_script(context, "deploy")
        load_script(context, "chef")
        load_script(context, "git")
      end

      def load_script(context, fragment)
        path = File.expand_path("../deployment/#{fragment}.rb", __FILE__)
        code = File.read(path)
        context.instance_eval(code, path)
      end
    end
  end
end

include Conan::Deployment::Helpers
