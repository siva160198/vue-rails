require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "admin can login, inspect their session, and logout" do
    post api_v1_session_url, params: { email_address: users(:one).email_address, password: "password" }, as: :json

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
  end
end
