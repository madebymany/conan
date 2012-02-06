lib = File.expand_path("../../lib", __FILE__)
$:.unshift lib unless $:.include?(lib)

require "test/unit"
require "fileutils"
require "digest/sha1"
require "conan/settings"

class SettingsTest < Test::Unit::TestCase

  def setup
    @original_directory = Dir.pwd
    @test_directory = "/tmp/#{Digest::SHA1.hexdigest(Time.now.to_s + rand.to_s)}"
    FileUtils.mkdir_p @test_directory
    Dir.chdir @test_directory
  end

  def teardown
    Dir.chdir @original_directory
    FileUtils.rm_rf @test_directory
  end

  def test_should_use_git_remote_to_get_application
    system "git init -q"
    system "git remote add origin git@example.com:foobar.git"
    settings = Conan::Settings.new
    assert_equal "foobar", settings["APPLICATION"]
  end

  def test_should_have_nil_for_application_if_not_found_via_git
    settings = Conan::Settings.new
    assert_nil settings["APPLICATION"]
  end

  def test_should_allow_override_of_application
    system "git init -q"
    system "git remote add origin git@example.com:foobar.git"
    settings = Conan::Settings.new
    assert_equal "foobar", settings["APPLICATION"]
    settings["APPLICATION"] = "baz"
    assert_equal "baz", settings["APPLICATION"]
  end

  def test_should_have_default_cookbooks
    settings = Conan::Settings.new
    assert_equal "git://github.com/madebymany/cookbooks.git", settings["COOKBOOK_REPOSITORY"]
    assert_equal "master", settings["COOKBOOK_BRANCH"]
  end

  def test_should_have_version
    settings = Conan::Settings.new
    assert_equal Conan::VERSION, settings["VERSION"]
  end

  def test_should_store_arbitrary_values
    settings = Conan::Settings.new
    settings["FOO"] = "bar"
    assert_equal "bar", settings["FOO"]
  end

  def test_should_default_values_to_nil
    settings = Conan::Settings.new
    assert_nil settings["FOO"]
  end
end
