lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require "conan/version"

Gem::Specification.new do |s|
  s.name        = "conan"
  s.version     = Conan::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Paul Battley"]
  s.email       = ["pbattley@gmail.com"]
  s.homepage    = "http://github.com/madebymany/conan"
  s.summary     = "Conan The Deployer"
  s.description = "Set up a project to enable the configuration of servers using Chef via Capistrano."
  s.add_dependency "json"

  s.executables  = ["conan"]
  s.files        = Dir["{bin,lib}/**/*"] + %w[README.md]
  s.require_path = 'lib'
end
