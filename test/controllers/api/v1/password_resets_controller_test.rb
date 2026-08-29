require "test_helper"

class Api::V1::PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "user resets password through a signed email link and old sessions are revoked" do
    user = users(:one)
    user.sessions.create!

    post api_v1_password_reset_url, params: { email_address: user.email_address }, as: :json

    assert_response :accepted
    assert_equal 1, ActionMailer::Base.deliveries.size
    token = token_from_email(ActionMailer::Base.deliveries.last)

    get api_v1_password_reset_url, params: { token: token }, as: :json
    assert_response :success

    patch api_v1_password_reset_url, params: {
      token: token,
      password: "the-new-secure-password",
      password_confirmation: "the-new-secure-password"
    }, as: :json

    assert_response :success
    assert User.authenticate_by(email_address: user.email_address, password: "the-new-secure-password")
    assert_not User.authenticate_by(email_address: user.email_address, password: "password")
    assert_empty user.sessions.reload

    get api_v1_password_reset_url, params: { token: token }, as: :json
    assert_response :unauthorized
  end

  test "unknown email receives the same accepted response without sending mail" do
    post api_v1_password_reset_url, params: { email_address: "unknown@example.com" }, as: :json

    assert_response :accepted
    assert_equal "Jika email terdaftar, link reset telah dikirim.", response.parsed_body["message"]
    assert_empty ActionMailer::Base.deliveries
  end

  test "invalid token cannot open or submit the reset form" do
    get api_v1_password_reset_url, params: { token: "invalid" }, as: :json
    assert_response :unauthorized
    assert_api_error "INVALID_PASSWORD_RESET_TOKEN"

    patch api_v1_password_reset_url, params: {
      token: "invalid",
      password: "the-new-secure-password",
      password_confirmation: "the-new-secure-password"
    }, as: :json
    assert_response :unauthorized
    assert_api_error "INVALID_PASSWORD_RESET_TOKEN"
  end

  test "invalid password does not invalidate a valid reset link" do
    user = users(:one)
    token = user.password_reset_token

    patch api_v1_password_reset_url, params: {
      token: token,
      password: "short",
      password_confirmation: "different"
    }, as: :json
    assert_response :unprocessable_content
    assert_api_error "VALIDATION_FAILED"
    assert response.parsed_body.dig("error", "details").present?

    get api_v1_password_reset_url, params: { token: token }, as: :json
    assert_response :success
  end

  private
    def token_from_email(email)
      reset_url = email.body.encoded[%r{http://localhost:5173/reset-password\?token=[^\s<"]+}]
      query = URI.parse(CGI.unescapeHTML(reset_url)).query
      URI.decode_www_form(query).to_h.fetch("token")
    end
end
