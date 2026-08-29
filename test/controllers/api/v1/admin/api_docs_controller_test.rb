require "test_helper"

class Api::V1::Admin::ApiDocsControllerTest < ActionDispatch::IntegrationTest
  test "authorized administrator can download the OpenAPI document" do
    sign_in_as users(:one)
    get api_v1_admin_api_docs_url

    assert_response :success
    assert_includes response.media_type, "yaml"
    assert_includes response.body, "openapi: 3.1.0"
  end

  test "member is forbidden" do
    sign_in_as users(:two)
    get api_v1_admin_api_docs_url

    assert_response :forbidden
    assert_api_error("FORBIDDEN")
  end
end
