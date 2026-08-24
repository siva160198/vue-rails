require "test_helper"

class Api::V1::PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "user resets password with email OTP and old sessions are revoked" do
    user = users(:one)
    user.sessions.create!

    post api_v1_password_reset_url,
      params: { email_address: user.email_address }, as: :json

    assert_response :accepted
    token = response.parsed_body.fetch("challenge_token")
    assert_equal 1, ActionMailer::Base.deliveries.size
    code = ActionMailer::Base.deliveries.last.body.encoded[/\b\d{6}\b/]

    patch api_v1_password_reset_url, params: {
      challenge_token: token,
      code: code,
      password: "the-new-secure-password",
      password_confirmation: "the-new-secure-password"
    }, as: :json

    assert_response :success
    assert User.authenticate_by(email_address: user.email_address, password: "the-new-secure-password")
    assert_not User.authenticate_by(email_address: user.email_address, password: "password")
    assert_empty user.sessions.reload
  end

  test "unknown email receives the same accepted response without sending mail" do
    assert_no_difference("PasswordResetChallenge.count") do
      post api_v1_password_reset_url,
        params: { email_address: "unknown@example.com" }, as: :json
    end

    assert_response :accepted
    assert response.parsed_body["challenge_token"].present?
    assert_empty ActionMailer::Base.deliveries
  end

  test "invalid OTP does not change the password" do
    challenge, = PasswordResetChallenge.issue_for!(users(:one))

    patch api_v1_password_reset_url, params: {
      challenge_token: challenge.token,
      code: "000000",
      password: "the-new-secure-password",
      password_confirmation: "the-new-secure-password"
    }, as: :json

    assert_response :unauthorized
    assert User.authenticate_by(email_address: users(:one).email_address, password: "password")
  end

  test "invalid password does not consume a valid OTP" do
    challenge, code = PasswordResetChallenge.issue_for!(users(:one))

    patch api_v1_password_reset_url, params: {
      challenge_token: challenge.token,
      code: code,
      password: "short",
      password_confirmation: "different"
    }, as: :json

    assert_response :unprocessable_content
    assert_not challenge.reload.consumed_at?
  end

  test "reset OTP can only be used once" do
    challenge, code = PasswordResetChallenge.issue_for!(users(:one))
    params = {
      challenge_token: challenge.token,
      code: code,
      password: "the-new-secure-password",
      password_confirmation: "the-new-secure-password"
    }

    patch api_v1_password_reset_url, params: params, as: :json
    assert_response :success

    patch api_v1_password_reset_url, params: params, as: :json
    assert_response :unauthorized
  end
end
