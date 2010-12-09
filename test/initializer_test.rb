lib = File.expand_path("../../lib", __FILE__)
$:.unshift lib unless $:.include?(lib)

require "test/unit"
require "digest/sha1"
require "fileutils"
require "conan/initializer"
require "json"

class InitializerTest < Test::Unit::TestCase

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

  def test_should_create_files_and_directories
    Conan::Initializer.run(".")
    assert File.exist?("config/servers.json")
  end

  def test_should_create_gemfile
    Conan::Initializer.run(".")
    assert File.exist?("Capfile")
  end

  def test_should_append_to_gemfile
    File.open("Gemfile", "w") do |f|
      f.puts "# existing content"
    end
    Conan::Initializer.run(".")
    content = File.read("Gemfile")
    assert_match /existing content/, content
    assert_match /gem "conan"/, content
  end

  def test_should_add_to_development_group_gemfile
    File.open("Gemfile", "w") do |f|
      f.puts "group :development do"
      f.puts "  gem \"existing\""
      f.puts "end"
    end
    Conan::Initializer.run(".")
    content = File.read("Gemfile")
    assert_match /group :development do\s+gem "conan"/, content
    assert_match /gem "existing"/, content
  end

  def test_should_create_Capfile
    Conan::Initializer.run(".")
    assert File.exist?("Capfile")
  end

  def test_should_create_gitignore
    Conan::Initializer.run(".")
    content = File.read(".gitignore")
    assert_match %r{^/deploy/chef/dna/generated\.json$}, content
  end

  def test_should_append_to_gitignore
    File.open(".gitignore", "w") do |f|
      f.puts "/existing/file"
    end
    Conan::Initializer.run(".")
    content = File.read(".gitignore")
    assert_match %r{^/existing/file$}, content
    assert_match %r{^/deploy/chef/dna/generated\.json$}, content
  end

  def test_should_have_valid_JSON_in_all_template_files
    json_files = Dir["#{Conan::Initializer::TEMPLATE_PATH}/**/*.json"]
    assert_not_equal [], json_files
    json_files.each do |path|
      assert_nothing_raised(path) do
        JSON.parse(File.read(path))
      end
    end
  end

  def test_should_load_git_submodules
    system "git init -q"
    Conan::Initializer.run(".")
    assert_not_equal [], Dir["deploy/chef/recipes/cookbooks/**/*"]
  end
end
