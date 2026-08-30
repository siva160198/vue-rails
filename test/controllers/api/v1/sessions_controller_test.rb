require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "reports disabled passkey authentication consistently" do
    post passkey_options_api_v1_session_url, params: { email_address: users(:one).email_address }, as: :json

    assert_response :unprocessable_content
    assert_api_error("WEBAUTHN_DISABLED")
  end

  test "passkey options do not reveal whether an email has a credential" do
    users(:one).webauthn_credentials.create!(external_id: "known-credential", public_key: "public-key", nickname: "Key")
    previous_rp = ENV["WEBAUTHN_RP_ID"]
    previous_origin = ENV["WEBAUTHN_ORIGIN"]
    ENV["WEBAUTHN_RP_ID"] = "www.example.com"
    ENV["WEBAUTHN_ORIGIN"] = "https://www.example.com"

    post passkey_options_api_v1_session_url, params: { email_address: users(:one).email_address }, as: :json
    existing_shape = response.parsed_body.keys.sort
    assert_response :success

    post passkey_options_api_v1_session_url, params: { email_address: "missing@example.com" }, as: :json
    assert_response :success
    assert_equal existing_shape, response.parsed_body.keys.sort
  ensure
    ENV["WEBAUTHN_RP_ID"] = previous_rp
    ENV["WEBAUTHN_ORIGIN"] = previous_origin
  end

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "admin completes email OTP before a session is created" do
    post api_v1_session_url, params: { email_address: users(:one).email_address, password: "password" }, as: :json

    assert_response :accepted
    assert response.parsed_body["otp_required"]
    challenge_token = response.parsed_body["challenge_token"]
    assert_not_empty challenge_token
    assert_equal 1, ActionMailer::Base.deliveries.size

    get api_v1_session_url, as: :json
    assert_response :unauthorized

    code = ActionMailer::Base.deliveries.last.body.encoded[/\b\d{6}\b/]
    post verify_otp_api_v1_session_url,
      params: { challenge_token: challenge_token, code: code }, as: :json

    assert_response :created
    assert_equal "admin", response.parsed_body.dig("user", "role")
    assert_equal 2, ActionMailer::Base.deliveries.size
    assert_match "Login baru terdeteksi", ActionMailer::Base.deliveries.last.body.encoded

    get api_v1_session_url, as: :json
    assert_response :success

    delete api_v1_session_url, as: :json
    assert_response :no_content

    get api_v1_session_url, as: :json
    assert_response :unauthorized
  end

  test "invalid credentials are rejected" do
    post api_v1_session_url, params: { email_address: users(:one).email_address, password: "wrong" }, as: :json
    assert_response :unauthorized
    assert_empty ActionMailer::Base.deliveries
  end

  test "repeated failures temporarily lock the account without changing the error early" do
    user = users(:two)
    8.times do
      post api_v1_session_url, params: { email_address: user.email_address, password: "wrong" }, as: :json
      assert_response :unauthorized
    end

    assert user.reload.login_locked?
    post api_v1_session_url, params: { email_address: user.email_address, password: "password" }, as: :json
    assert_response :too_many_requests
    assert_api_error("LOGIN_TEMPORARILY_BLOCKED")
    assert AuditLog.exists?(action: "session.login_blocked", actor: user)
    assert_equal 1, ActionMailer::Base.deliveries.count { |mail| mail.subject == "Percobaan login mencurigakan pada akun Anda" }
  end

  test "optional CAPTCHA is required after elevated risk and a verified challenge allows recovery" do
    user = users(:two)
    3.times { post api_v1_session_url, params: { email_address: user.email_address, password: "wrong" }, as: :json }

    verifier = Struct.new(:valid) do
      def enabled? = true
      def site_key = "test-site-key"
      def verify(token:, remote_ip:) = valid && token == "verified" && remote_ip.present?
    end.new(false)
    Api::V1::SessionsController.captcha_verifier = verifier

    post api_v1_session_url, params: { email_address: user.email_address, password: "password" }, as: :json
    assert_response :unprocessable_content
    assert_api_error("CAPTCHA_REQUIRED")
    assert_equal "test-site-key", response.parsed_body.dig("error", "details", "captcha_site_key")

    verifier.valid = true
    post api_v1_session_url, params: { email_address: user.email_address, password: "password", captcha_token: "verified" }, as: :json
    assert_response :accepted
    assert_equal 0, user.reload.failed_login_attempts
  ensure
    Api::V1::SessionsController.captcha_verifier = CaptchaVerifier
  end

  test "administrator must perform MFA again and cannot reuse trusted-browser bypass" do
    user = users(:one)
    challenge, code = LoginChallenge.issue_for!(user)
    post verify_otp_api_v1_session_url, params: { challenge_token: challenge.token, code: code }, as: :json
    assert_response :created
    delete api_v1_session_url, as: :json
    ActionMailer::Base.deliveries.clear

    post api_v1_session_url, params: { email_address: user.email_address, password: "password" }, as: :json

    assert_response :accepted
    assert response.parsed_body.fetch("otp_required")
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "authentication errors follow Accept-Language" do
    post api_v1_session_url,
      params: { email_address: users(:one).email_address, password: "wrong" },
      headers: { "Accept-Language" => "en-US,en;q=0.9" }, as: :json

    assert_response :unauthorized
    assert_api_error "INVALID_CREDENTIALS", message: "Invalid email or password."
  end

  test "inactive account receives a support contact message after valid credentials" do
    user = users(:two)
    user.update!(active: false)

    post api_v1_session_url,
      params: { email_address: user.email_address, password: "password" }, as: :json

    assert_response :forbidden
    assert_api_error "ACCOUNT_INACTIVE", message: "Akun Anda nonaktif. Silakan hubungi example@mail.com."
    assert_empty ActionMailer::Base.deliveries
  end

  test "inactive account with wrong password does not reveal its status" do
    user = users(:two)
    user.update!(active: false)

    post api_v1_session_url,
      params: { email_address: user.email_address, password: "wrong" }, as: :json

    assert_response :unauthorized
    assert_api_error "INVALID_CREDENTIALS", message: "Email atau password tidak valid."
  end

  test "verified OTP is trusted in the same browser for one hour" do
    user = users(:two)
    challenge, code = LoginChallenge.issue_for!(user)

    post verify_otp_api_v1_session_url,
      params: { challenge_token: challenge.token, code: code }, as: :json
    assert_response :created

    delete api_v1_session_url, as: :json
    ActionMailer::Base.deliveries.clear

    post api_v1_session_url,
      params: { email_address: user.email_address, password: "password" }, as: :json

    assert_response :created
    assert_equal false, response.parsed_body["otp_required"]
    assert_equal user.id, response.parsed_body.dig("user", "id")
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal "Login baru ke akun Anda", ActionMailer::Base.deliveries.last.subject
  end

  test "OTP trust expires after one hour" do
    user = users(:one)
    challenge, code = LoginChallenge.issue_for!(user)

    post verify_otp_api_v1_session_url,
      params: { challenge_token: challenge.token, code: code }, as: :json
    delete api_v1_session_url, as: :json
    ActionMailer::Base.deliveries.clear

    travel 61.minutes do
      post api_v1_session_url,
        params: { email_address: user.email_address, password: "password" }, as: :json

      assert_response :accepted
      assert response.parsed_body["otp_required"]
      assert_equal 1, ActionMailer::Base.deliveries.size
    end
  end

  test "unverified account is identified and directed to OTP verification" do
    user = users(:two)
    user.update!(email_verified_at: nil)

    post api_v1_session_url, params: { email_address: user.email_address, password: "password" }, as: :json

    assert_response :accepted
    assert response.parsed_body["account_unverified"]
    assert response.parsed_body["otp_required"]
    assert_not_empty response.parsed_body["challenge_token"]
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "invalid OTP is rejected without creating a session" do
    challenge, = LoginChallenge.issue_for!(users(:one))

    post verify_otp_api_v1_session_url,
      params: { challenge_token: challenge.token, code: "000000" }, as: :json

    assert_response :unauthorized
    assert_equal 1, challenge.reload.attempts_count

    get api_v1_session_url, as: :json
    assert_response :unauthorized
  end

  test "OTP can only be used once" do
    challenge, code = LoginChallenge.issue_for!(users(:one))

    post verify_otp_api_v1_session_url,
      params: { challenge_token: challenge.token, code: code }, as: :json
    assert_response :created

    delete api_v1_session_url, as: :json
    post verify_otp_api_v1_session_url,
      params: { challenge_token: challenge.token, code: code }, as: :json
    assert_response :unauthorized
  end

  test "recovery code signs in once and session count is bounded" do
    user = users(:one)
    recovery_code = user.regenerate_recovery_codes!.first
    12.times { user.sessions.create! }
    challenge, = LoginChallenge.issue_for!(user)

    post verify_otp_api_v1_session_url,
      params: { challenge_token: challenge.token, code: recovery_code }, as: :json

    assert_response :created
    assert_operator user.sessions.reload.count, :<=, 10
    assert_equal "session.recovery_code_login", AuditLog.last.action

    delete api_v1_session_url, as: :json
    next_challenge, = LoginChallenge.issue_for!(user)
    post verify_otp_api_v1_session_url,
      params: { challenge_token: next_challenge.token, code: recovery_code }, as: :json
    assert_response :unauthorized
  end

  test "expired OTP is rejected" do
    challenge, code = LoginChallenge.issue_for!(users(:one))
    challenge.update!(expires_at: 1.minute.ago)

    post verify_otp_api_v1_session_url,
      params: { challenge_token: challenge.token, code: code }, as: :json

    assert_response :unauthorized
  end

  test "resending too soon is rate limited" do
    challenge, = LoginChallenge.issue_for!(users(:one))

    post resend_otp_api_v1_session_url,
      params: { challenge_token: challenge.token }, as: :json

    assert_response :too_many_requests
    assert_api_error "OTP_RESEND_TOO_SOON"
  end

  test "resending issues a new challenge and invalidates the previous one" do
    challenge, old_code = LoginChallenge.issue_for!(users(:one))
    old_token = challenge.token

    travel 61.seconds do
      post resend_otp_api_v1_session_url,
        params: { challenge_token: old_token }, as: :json

      assert_response :accepted
      new_token = response.parsed_body["challenge_token"]
      assert_not_equal old_token, new_token
      assert challenge.reload.consumed_at?

      post verify_otp_api_v1_session_url,
        params: { challenge_token: old_token, code: old_code }, as: :json
      assert_response :unauthorized
    end
  end
end
