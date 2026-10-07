require "test_helper"

class SessionUnlockTest < ActionDispatch::IntegrationTest
  test "role permission changes permanently revoke existing device trust" do
    member = users(:two)
    device, = TrustedDevice.issue!(member, user_agent: "Test")
    previous_version = member.authentication_version
    admin = users(:one)
    sign_in_as(admin)
    role = member.role_record
    patch api_v1_admin_role_url(role), params: { permission_keys: [], step_up_token: step_up_token_for(admin, "admin_role_change") }, as: :json
    assert_response :success
    assert_equal previous_version + 1, member.reload.authentication_version
    assert_operator device.reload.expires_at, :<=, Time.current
  end

  test "unlock needs password and is bound to the original account" do
    user = users(:two)
    user.update!(login_otp_required: false)
    post api_v1_session_url, params: { email_address: user.email_address, password: "password" }, as: :json
    context = response.parsed_body.fetch("user").fetch("unlock_token")
    delete api_v1_session_url, as: :json
    post unlock_api_v1_session_url, params: { unlock_token: context, email_address: users(:one).email_address, password: "wrong" }, as: :json
    assert_response :unauthorized
    assert_api_error("INVALID_CREDENTIALS")
    post unlock_api_v1_session_url, params: { unlock_token: context, email_address: users(:one).email_address, password: "password" }, as: :json
    assert_response :created
    assert_equal user.id, response.parsed_body.dig("user", "id")
  end

  test "unlock rejects tampered expired and revoked contexts" do
    user = users(:two)
    token = Rails.application.message_verifier(:session_unlock).generate({ user_id: user.id, authentication_version: user.authentication_version }, expires_in: 1.minute)
    [ "tampered", token + "x" ].each do |context|
      post unlock_api_v1_session_url, params: { unlock_token: context, password: "password" }, as: :json
      assert_response :unauthorized
      assert_api_error("INVALID_UNLOCK_CONTEXT")
    end
    travel 2.minutes do
      post unlock_api_v1_session_url, params: { unlock_token: token, password: "password" }, as: :json
      assert_response :unauthorized
    end
    user.increment!(:authentication_version)
    post unlock_api_v1_session_url, params: { unlock_token: token, password: "password" }, as: :json
    assert_response :unauthorized
  end

  test "opt in trust lasts beyond short OTP trust but requires binding for new sessions" do
    user = users(:two)
    challenge, code = LoginChallenge.issue_for!(user)
    post verify_otp_api_v1_session_url, params: { challenge_token: challenge.token, code: code, trust_device: true }, as: :json
    assert_response :created
    assert_equal 1, user.trusted_devices.count
    token = cookies[:trusted_device_token]
    binding = cookies[:trusted_device_binding]
    assert token.present?
    assert binding.present?
    delete api_v1_session_url, as: :json
    travel 2.days do
      post api_v1_session_url, params: { email_address: user.email_address, password: "password" }, as: :json
      assert_response :created
      assert_not_equal token, cookies[:trusted_device_token]
      assert user.sessions.last.trusted_device_id.present?
      cookies.delete("trusted_device_binding")
      get api_v1_session_url, as: :json
      assert_response :unauthorized
      post api_v1_session_url, params: { email_address: user.email_address, password: "password" }, as: :json
      assert_response :accepted
    end
  end

  test "administrator cannot opt into trust and mismatched unlock OTP is rejected" do
    challenge, code = LoginChallenge.issue_for!(users(:one))
    token = Rails.application.message_verifier(:session_unlock).generate({ user_id: users(:two).id, authentication_version: users(:two).authentication_version }, expires_in: 1.hour)
    post verify_otp_api_v1_session_url, params: { challenge_token: challenge.token, code: code, unlock_token: token }, as: :json
    assert_response :unauthorized
    post verify_otp_api_v1_session_url, params: { challenge_token: challenge.token, code: code, trust_device: true }, as: :json
    assert_response :created
    assert_empty users(:one).trusted_devices
  end
end
