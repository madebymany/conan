module Conan
  class Deployment
    module Helpers
      def _cset(name, *args, &block)
        unless exists?(name)
          set(name, *args, &block)
        end
      end

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

      def git_tag(source, dest)
        system "git fetch origin --tags"
        sha1 = `git rev-parse "#{source}"`
        system %{git update-ref "refs/tags/#{dest}" #{sha1}}
        system %{git push -f origin tag #{dest}}
      end


      def git_log(from, to)
       begin  
          run_locally("git log #{real_revision(from)}..#{real_revision(to)}")
       rescue RuntimeError
          #runtime error probably means there is no initial tag and no deploys have been done
          return run_locally("git log #{real_revision(to)}")
       end

      end

      def real_revision(tag)
        source.local.query_revision(tag) { |cmd| with_env("LC_ALL", "C") { run_locally(cmd) } }
      end

      def add_role(*roles)
        roles = Hash.new{ |h,k| h[k] = [] }

        #init this manually otherwise we can run into problems where no server has the app role and 
        #the above initialiser can't run while iterating over it
        roles[:app] = []

        server_config.each do |s, c|
          c["roles"].each do |r|
            roles[r.to_sym] << s
          end
        end unless server_config.nil?

        roles.each do |r, ss|
          next unless roles.include?(r)
          ss.each_with_index do |s, i|
            role r, s, :primary => (i == 0), :no_release => !roles[:app].include?(s)
          end
        end
      end
    end

    class <<self
      def define_tasks(context)
        load_script(context, "deployment/deploy")
        load_script(context, "deployment/chef")

        load_script(context, "deployment/git") 

        load_script(context, "cloud/tasks")
        
        begin
          rails_v = context.variables[:rails_version]
          rails_v = `bundle exec rails -v`.chomp.split(' ').last unless rails_v
          if Gem::Version.new(rails_v) > Gem::Version.new('3.1.0')
            load_script(context, "deployment/assets")
          end
        rescue
          #not a rails or 3.1 app or bundle failed
        end

      end

      def load_script(context, fragment)
        path = File.expand_path("../#{fragment}.rb", __FILE__)
        code = File.read(path)
        context.instance_eval(code, path)
      end
    end
  end
end

include Conan::Deployment::Helpers
