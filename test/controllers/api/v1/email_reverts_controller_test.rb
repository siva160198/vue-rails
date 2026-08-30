require "test_helper"

class Api::V1::EmailRevertsControllerTest < ActionDispatch::IntegrationTest
  test "restores the previous email and revokes sessions using a single-purpose token" do
    user = users(:two)
    raw = SecureRandom.urlsafe_base64(32)
    user.update_columns(
      email_address: "attacker@example.com",
      pending_email_revert_address: SecurityEncryptor.encrypt("two@example.com", purpose: "email-revert"),
      pending_email_revert_digest: Digest::SHA256.hexdigest(raw),
      pending_email_revert_expires_at: 1.hour.from_now
    )
    user.sessions.create!
    token = Rails.application.message_verifier(:email_revert).generate({ user_id: user.id, token: raw }, expires_in: 1.hour)

    post api_v1_email_revert_url, params: { token: token }, as: :json

    assert_response :success
    assert_equal "two@example.com", user.reload.email_address
    assert_empty user.sessions
    assert AuditLog.exists?(action: "account.email_change_reverted", actor: user)
  end

  test "rejects an invalid token without revealing account data" do
    post api_v1_email_revert_url, params: { token: "invalid" }, as: :json
    assert_response :unauthorized
    assert_api_error("INVALID_EMAIL_REVERT_TOKEN")
  end
end
