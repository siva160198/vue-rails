require "test_helper"

class TotpAuthenticatorTest < ActiveSupport::TestCase
  test "matches the RFC 6238 SHA1 test vector truncated to six digits" do
    secret = Base64.strict_encode64("12345678901234567890")
    assert_equal "287082", TotpAuthenticator.code(secret, at: Time.at(59))
    assert TotpAuthenticator.valid?(secret, "287082", at: Time.at(59))
    assert_equal 1, TotpAuthenticator.matching_counter(secret, "287082", at: Time.at(59))
    assert_not TotpAuthenticator.valid?(secret, "000000", at: Time.at(59))
  end

  test "builds an authenticator provisioning URI without exposing the raw binary secret" do
    secret = TotpAuthenticator.generate_secret
    uri = TotpAuthenticator.provisioning_uri(secret: secret, email: "one@example.com", issuer: "Vue Rails")
    assert uri.start_with?("otpauth://totp/")
    assert_includes uri, "secret=#{TotpAuthenticator.base32_secret(secret)}"
    assert_not_includes uri, secret
  end
end
