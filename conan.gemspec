lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require "conan/version"

Gem::Specification.new do |s|
  s.name        = "conan"
  s.version     = Conan::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Paul Battley","Stuart Eccles"]
  s.email       = ["stuart@madebymany.co.uk"]
  s.homepage    = "http://github.com/madebymany/conan"
  s.summary     = "Conan The Deployer"
  s.description = "Set up a project to enable the provision of infrastructure through AWS and the configuration of servers using Chef via Capistrano."
  s.add_dependency "json", "~> 1.6.1"
  s.add_dependency "capistrano"
  s.add_dependency "fog"
  s.executables  = ["conan"]
  s.files        = Dir["{bin,lib}/**/*"] + %w[README.md]
  s.require_path = 'lib'
end
