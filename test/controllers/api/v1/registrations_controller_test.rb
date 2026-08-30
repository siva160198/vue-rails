require "test_helper"

class Api::V1::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "user registers as a member and verifies their email with OTP" do
    assert_difference("User.count", 1) do
      post api_v1_registration_url, params: {
        email_address: "new@example.com",
        password: "a-secure-password",
        password_confirmation: "a-secure-password",
        role: "admin"
      }, as: :json
    end

    assert_response :created
    user = User.find_by!(email_address: "new@example.com")
    assert user.member?
    assert_not user.email_verified?
    assert_equal 1, ActionMailer::Base.deliveries.size
    challenge_token = response.parsed_body.fetch("challenge_token")

    get api_v1_session_url, as: :json
    assert_response :unauthorized

    code = ActionMailer::Base.deliveries.last.body.encoded[/\b\d{6}\b/]
    post verify_otp_api_v1_session_url, params: {
      challenge_token: challenge_token,
      code: code
    }, as: :json

    assert_response :created
    assert user.reload.email_verified?
    assert_equal "member", response.parsed_body.dig("user", "role")

    get api_v1_session_url, as: :json
    assert_response :success
  end

  test "duplicate email is rejected" do
    assert_no_difference("User.count") do
      post api_v1_registration_url, params: {
        email_address: users(:one).email_address,
        password: "password",
        password_confirmation: "password"
      }, as: :json
    end

    assert_response :unprocessable_content
    assert_api_error "VALIDATION_FAILED"
    assert response.parsed_body.dig("error", "details").present?
    assert_empty ActionMailer::Base.deliveries
  end

  test "existing unverified account receives a new verification challenge" do
    user = users(:two)
    user.update!(email_verified_at: nil)

    assert_no_difference("User.count") do
      post api_v1_registration_url, params: {
        email_address: user.email_address.upcase,
        password: "password",
        password_confirmation: "password"
      }, as: :json
    end

    assert_response :accepted
    assert response.parsed_body["account_unverified"]
    assert response.parsed_body["otp_required"]
    assert_not_empty response.parsed_body["challenge_token"]
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "unverified registration requires the existing password and respects resend cooldown" do
    user = users(:two)
    user.update!(email_verified_at: nil)
    challenge, = LoginChallenge.issue_for!(user)

    post api_v1_registration_url, params: { email_address: user.email_address, password: "wrong-password", password_confirmation: "wrong-password" }, as: :json
    assert_response :unprocessable_content
    assert_api_error("VALIDATION_FAILED")
    assert_equal challenge.id, user.login_challenges.active.first.id
    assert_empty ActionMailer::Base.deliveries

    post api_v1_registration_url, params: { email_address: user.email_address, password: "password", password_confirmation: "password" }, as: :json
    assert_response :accepted
    returned = LoginChallenge.find_signed(response.parsed_body.fetch("challenge_token"), purpose: :login_otp)
    assert_equal challenge.id, returned.id
    assert_empty ActionMailer::Base.deliveries
  end

  test "short or mismatched password is rejected" do
    assert_no_difference("User.count") do
      post api_v1_registration_url, params: {
        email_address: "new@example.com",
        password: "short",
        password_confirmation: "different"
      }, as: :json
    end

    assert_response :unprocessable_content
    assert_api_error "VALIDATION_FAILED"
    assert response.parsed_body.dig("error", "details").present?
    assert_empty ActionMailer::Base.deliveries
  end
end
