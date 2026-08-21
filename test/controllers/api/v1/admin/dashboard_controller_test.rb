require "test_helper"

class Api::V1::Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "anonymous users receive unauthorized" do
    get api_v1_admin_dashboard_url, as: :json
    assert_response :unauthorized
  end

  test "members receive forbidden" do
    sign_in_as users(:two)
    get api_v1_admin_dashboard_url, as: :json
    assert_response :forbidden
  end

  test "admins can view the dashboard" do
    sign_in_as users(:one)
    get api_v1_admin_dashboard_url, as: :json

    assert_response :success
    assert_equal "admin", response.parsed_body.dig("user", "role")
    assert response.parsed_body.dig("metrics", "users") >= 2
  end
end
