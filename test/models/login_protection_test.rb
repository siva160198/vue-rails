require "test_helper"

class LoginProtectionTest < ActiveSupport::TestCase
  test "blocks an IP that fails against many account digests" do
    protection = LoginProtection.new(email_address: "target@example.com", ip_address: "192.0.2.50")
    20.times do |index|
      LoginAttempt.create!(email_digest: "digest-#{index % 5}", ip_address: "192.0.2.50", successful: false)
    end

    assert protection.ip_attack?
  end

  test "successful authentication clears account lock state" do
    user = users(:two)
    user.update!(failed_login_attempts: 5, locked_until: 10.minutes.from_now)

    LoginProtection.new(email_address: user.email_address, ip_address: "192.0.2.51").record_success!(user)

    assert_equal 0, user.reload.failed_login_attempts
    assert_nil user.locked_until
  end


  test "progressive delay is bounded and trusted networks bypass risk" do
    protection = LoginProtection.new(email_address: "target@example.com", ip_address: "192.0.2.60")
    6.times { LoginAttempt.create!(email_digest: protection.email_digest, ip_address: "192.0.2.60", successful: false) }
    assert_operator protection.delay_seconds, :>, 0.15
    assert_operator protection.delay_seconds, :<=, LoginProtection::MAX_DELAY

    previous = ENV["TRUSTED_LOGIN_NETWORKS"]
    ENV["TRUSTED_LOGIN_NETWORKS"] = "192.0.2.0/24"
    begin
      assert_equal 0, protection.risk_score(users(:two))
      assert_not protection.captcha_required?(users(:two))
    ensure
      ENV["TRUSTED_LOGIN_NETWORKS"] = previous
    end
  end
end
