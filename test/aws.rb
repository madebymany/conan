lib = File.expand_path("../../lib", __FILE__)
$:.unshift lib unless $:.include?(lib)

require "test/unit"
require "json"
require "fileutils"
require "conan/cloud/aws/provision"
require "fog"

class SettingsTest < Test::Unit::TestCase

  def setup
    @config = JSON.parse(File.read("lib/conan/template/config/aws.json"))
  end

  def teardown
  end

  def test_should_build_mock_env
    Fog.mock!
    stage = "staging"
    AWS::Provision.build_env(stage, @config[stage])
  end
end
