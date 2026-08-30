require "test_helper"

class EmailPrivacyDigestTest < ActiveSupport::TestCase
  test "normalizes email and uses a keyed digest distinct from legacy SHA-256" do
    digest = EmailPrivacyDigest.call(" User@Example.com ")

    assert_equal digest, EmailPrivacyDigest.call("user@example.com")
    assert_not_equal EmailPrivacyDigest.legacy("user@example.com"), digest
    assert_match(/\A[0-9a-f]{64}\z/, digest)
  end
end
