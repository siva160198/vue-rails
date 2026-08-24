require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
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
