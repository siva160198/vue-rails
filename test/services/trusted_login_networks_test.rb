require "test_helper"

class TrustedLoginNetworksTest < ActiveSupport::TestCase
  test "matches only configured server-side CIDRs" do
    previous = ENV["TRUSTED_LOGIN_NETWORKS"]
    ENV["TRUSTED_LOGIN_NETWORKS"] = "10.0.0.0/8,2001:db8::/32"
    begin
      assert TrustedLoginNetworks.include?("10.2.3.4")
      assert TrustedLoginNetworks.include?("2001:db8::10")
      assert_not TrustedLoginNetworks.include?("192.0.2.1")
    ensure
      ENV["TRUSTED_LOGIN_NETWORKS"] = previous
    end
  end

  test "fails closed for invalid addresses" do
    assert_not TrustedLoginNetworks.include?("not-an-ip")
  end
end
