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
        password: "a-secure-password",
        password_confirmation: "a-secure-password"
      }, as: :json
    end

    assert_response :unprocessable_content
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
    assert_empty ActionMailer::Base.deliveries
  end
end
