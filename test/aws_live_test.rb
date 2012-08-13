lib = File.expand_path("../../lib", __FILE__)
$:.unshift lib unless $:.include?(lib)

require "test/unit"
require "json"
require "fileutils"
require "conan/cloud/aws/provision"
require "fog"

class AWSLiveProvisionTest < Test::Unit::TestCase

  def setup
  end

  def teardown
  end


  def test_should_build_from_min_json
    stage = "staging"
    config = JSON.parse(File.read("test/aws_min_live.json"))[stage]
    AWS::Provision.new(config, stage).build_env

    compute = Fog::Compute[:aws]

    assert_equal 1, compute.key_pairs.all.size
    assert_equal "keypair-name", compute.key_pairs.all.first.name

    sg = compute.security_groups.get("staging-default")
    assert_equal false, sg.nil?

    has_port_22 = false
    has_port_80 = false
    sg.ip_permissions.each do |ip_permission|
      has_port_22 = true if (ip_permission["fromPort"] == 22 and ip_permission["toPort"] == 22)
      has_port_80 = true if (ip_permission["fromPort"] == 80 and ip_permission["toPort"] == 80)
    end

    assert_equal true, has_port_22
    assert_equal true, has_port_80

    ec2_servers = compute.servers.all
    assert_equal 1, ec2_servers.size

    app1 = ec2_servers.first

    assert_equal true, app1.monitoring
    assert_equal "ami-7000f019", app1.image_id
    assert_equal "m1.small", app1.flavor_id
    assert_equal "us-east-1a", app1.availability_zone
    assert_equal "staging-app1", app1.tags[:name]
    assert_equal "staging", app1.tags[:stage]
    assert_equal "app, db, staging", app1.tags[:roles]
    assert_equal "staging-default", app1.groups.first
    assert_equal "keypair-name", app1.key_name

  end

end
