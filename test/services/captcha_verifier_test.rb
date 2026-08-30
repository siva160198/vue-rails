require "test_helper"

class CaptchaVerifierTest < ActiveSupport::TestCase
  test "is disabled unless both keys exist" do
    assert_not CaptchaVerifier.enabled?
    assert CaptchaVerifier.verify(token: nil, remote_ip: "192.0.2.1")
  end

  test "rejects missing or oversized tokens before network access" do
    previous_site = ENV["TURNSTILE_SITE_KEY"]
    previous_secret = ENV["TURNSTILE_SECRET_KEY"]
    ENV["TURNSTILE_SITE_KEY"] = "test-site"
    ENV["TURNSTILE_SECRET_KEY"] = "test-secret"
    begin
      assert_not CaptchaVerifier.verify(token: nil, remote_ip: "192.0.2.1")
      assert_not CaptchaVerifier.verify(token: "x" * 2_049, remote_ip: "192.0.2.1")
    ensure
      ENV["TURNSTILE_SITE_KEY"] = previous_site
      ENV["TURNSTILE_SECRET_KEY"] = previous_secret
    end
  end
end
