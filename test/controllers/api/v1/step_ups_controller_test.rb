require "test_helper"

class Api::V1::StepUpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    ActionMailer::Base.deliveries.clear
  end

  test "issues a reusable short-lived grant after password and OTP verification" do
    post api_v1_step_up_url, params: { purpose: "account_security", current_password: "password" }, as: :json
    assert_response :accepted
    token = response.parsed_body.fetch("challenge_token")
    code = ActionMailer::Base.deliveries.last.body.encoded[/\b\d{6}\b/]

    post verify_api_v1_step_up_url, params: { purpose: "account_security", challenge_token: token, code: code }, as: :json

    assert_response :success
    assert response.parsed_body.fetch("step_up_token")
    assert_equal StepUpChallenge::GRANT_LIFETIME.to_i, response.parsed_body.fetch("expires_in")
    assert AuditLog.exists?(action: "account.step_up_verified", actor: @user)
  end

  test "rejects unknown purposes and invalid current password" do
    post api_v1_step_up_url, params: { purpose: "admin_role", current_password: "password" }, as: :json
    assert_response :unprocessable_content
    assert_api_error("INVALID_STEP_UP_PURPOSE")

    post api_v1_step_up_url, params: { purpose: "account_security", current_password: "wrong" }, as: :json
    assert_response :unauthorized
    assert_api_error("CURRENT_PASSWORD_INVALID")
  end
end
