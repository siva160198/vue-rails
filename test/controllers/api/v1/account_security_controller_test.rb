require "test_helper"

class Api::V1::AccountSecurityControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "lists only the current user's security history" do
    own = AuditLog.record!(action: "session.login", actor: @user, auditable: @user)
    other = AuditLog.record!(action: "session.login", actor: users(:two), auditable: users(:two))

    get api_v1_account_security_url, as: :json

    assert_response :success
    ids = response.parsed_body.fetch("events").pluck("id")
    assert_includes ids, own.id
    assert_not_includes ids, other.id
    assert response.parsed_body.key?("pagination")
  end

  test "keeps legacy and keyed failed-login history visible during digest migration" do
    keyed = AuditLog.record!(action: "session.login_failed", metadata: { email_digest: EmailPrivacyDigest.call(@user.email_address) })
    legacy = AuditLog.record!(action: "session.login_failed", metadata: { email_digest: EmailPrivacyDigest.legacy(@user.email_address) })

    get api_v1_account_security_url, as: :json

    ids = response.parsed_body.fetch("events").pluck("id")
    assert_includes ids, keyed.id
    assert_includes ids, legacy.id
  end

  test "changes password and revokes every other session" do
    other_session = @user.sessions.create!(ip_address: "127.0.0.2")

    patch password_api_v1_account_security_url, params: {
      password: "a-new-password-123", password_confirmation: "a-new-password-123"
    }, headers: { "X-Step-Up-Token" => step_up_token_for(@user, "password_change") }, as: :json

    assert_response :success
    assert @user.reload.authenticate("a-new-password-123")
    assert_not Session.exists?(other_session.id)
    assert AuditLog.exists?(action: "account.password_changed", actor: @user)
  end

  test "rejects an invalid current password" do
    patch password_api_v1_account_security_url, params: {
      current_password: "wrong", password: "a-new-password-123", password_confirmation: "a-new-password-123"
    }, as: :json

    assert_response :unauthorized
    assert_api_error("CURRENT_PASSWORD_INVALID")
  end

  test "requires a purpose-bound step-up token to change password" do
    patch password_api_v1_account_security_url, params: { password: "a-new-password-123", password_confirmation: "a-new-password-123" }, as: :json
    assert_response :unauthorized
    assert_api_error("STEP_UP_REQUIRED")
  end

  test "enrolls and verifies an authenticator app" do
    old_secret = TotpAuthenticator.generate_secret
    @user.update!(totp_secret: old_secret, totp_enabled_at: Time.current)
    post request_totp_api_v1_account_security_url, headers: { "X-Step-Up-Token" => step_up_token_for(@user, "totp_enroll") }, as: :json
    assert_response :success
    assert response.parsed_body.fetch("provisioning_uri").start_with?("otpauth://")
    assert_equal old_secret, @user.reload.totp_secret
    assert @user.totp_enabled?

    code = TotpAuthenticator.code(@user.reload.pending_totp_secret)
    post verify_totp_api_v1_account_security_url, params: { code: code }, as: :json
    assert_response :success
    assert @user.reload.totp_enabled?
    assert_nil @user.pending_totp_secret
    assert_not_equal old_secret, @user.totp_secret
  end

  test "requires step-up before creating a pending authenticator secret" do
    post request_totp_api_v1_account_security_url, as: :json
    assert_response :unauthorized
    assert_api_error("STEP_UP_REQUIRED")
    assert_nil @user.reload.pending_totp_secret
  end

  test "verifies a new email before changing it" do
    challenge = @user.email_change_challenges.create!(email_address: "new-address@example.com", code: "123456", expires_at: 10.minutes.from_now)

    post verify_email_api_v1_account_security_url, params: { challenge_token: challenge.token, code: "123456" }, as: :json

    assert_response :success
    assert_equal "new-address@example.com", @user.reload.email_address
    assert @user.email_verified?
  end

  test "requires OTP after password confirmation to regenerate recovery codes" do
    post request_recovery_codes_api_v1_account_security_url, params: { current_password: "password" }, as: :json
    assert_response :accepted
    token = response.parsed_body.fetch("challenge_token")

    post verify_recovery_codes_api_v1_account_security_url, params: { challenge_token: token, code: "000000" }, as: :json
    assert_response :unauthorized
    assert_empty @user.reload.recovery_code_digests

    challenge = @user.step_up_challenges.create!(purpose: "recovery_codes", code: "123456", expires_at: 5.minutes.from_now)
    post verify_recovery_codes_api_v1_account_security_url, params: { challenge_token: challenge.token, code: "123456" }, as: :json
    assert_response :success
    assert_equal 8, response.parsed_body.fetch("recovery_codes").size
    assert_equal 8, @user.reload.recovery_code_digests.size
  end
end
