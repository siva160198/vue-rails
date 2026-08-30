require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "recovery code can only be consumed once" do
    user = users(:one)
    code = user.regenerate_recovery_codes!.first

    assert user.consume_recovery_code(code)
    assert_not user.consume_recovery_code(code)
  end


  test "TOTP code cannot be replayed in the same time window" do
    user = users(:one)
    secret = TotpAuthenticator.generate_secret
    now = Time.current.change(usec: 0)
    user.update!(totp_secret: secret, totp_enabled_at: now)
    code = TotpAuthenticator.code(secret, at: now)

    assert user.verify_totp(code)
    assert_not user.verify_totp(code)
    assert_equal now.to_i / TotpAuthenticator::PERIOD, user.reload.last_totp_counter
  end

  test "a newer TOTP counter remains valid after replay protection" do
    user = users(:one)
    secret = TotpAuthenticator.generate_secret
    now = Time.current.change(usec: 0)
    user.update!(totp_secret: secret, totp_enabled_at: now)

    assert user.verify_totp(TotpAuthenticator.code(secret, at: now))
    travel_to(now + TotpAuthenticator::PERIOD) do
      assert user.verify_totp(TotpAuthenticator.code(secret, at: Time.current))
    end
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end
end
