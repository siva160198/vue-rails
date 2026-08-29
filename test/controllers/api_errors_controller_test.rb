require "test_helper"

class ApiErrorsControllerTest < ActionDispatch::IntegrationTest
  test "unknown API routes return the standard error contract" do
    get "/api/v1/does-not-exist", as: :json

    assert_response :not_found
    assert_api_error "RESOURCE_NOT_FOUND"
  end

  test "missing API records return the standard error contract" do
    sign_in_as users(:one)

    get api_v1_admin_users_url, params: { page: 1 }, as: :json
    patch api_v1_admin_user_url(id: 999_999), params: { active: false }, as: :json

    assert_response :not_found
    assert_api_error "RESOURCE_NOT_FOUND"
  end

  test "malformed JSON returns the standard error contract" do
    post api_v1_session_url,
      params: '{"email_address":',
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :bad_request
    assert_api_error "INVALID_JSON"
  end
end
