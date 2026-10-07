require "test_helper"

class Api::V1::Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "anonymous users receive unauthorized" do
    get api_v1_admin_dashboard_url, as: :json
    assert_response :unauthorized
    assert_api_error "AUTHENTICATION_REQUIRED"
  end

  test "members receive forbidden" do
    sign_in_as users(:two)
    get api_v1_admin_dashboard_url, as: :json
    assert_response :forbidden
    assert_api_error "FORBIDDEN"
  end

  test "admins can view the dashboard" do
    sign_in_as users(:one)
    get api_v1_admin_dashboard_url, as: :json

    assert_response :success
    assert_equal "admin", response.parsed_body.dig("user", "role")
    assert response.parsed_body.dig("metrics", "users") >= 2
    assert_equal 7, response.parsed_body.dig("report", "current").length
    assert_equal "UTC", response.parsed_body.dig("report", "range", "timezone")
  end
  test "invalid report range returns localized field errors" do
    sign_in_as users(:one)
    get api_v1_admin_dashboard_url(start_date: "invalid"), as: :json
    assert_response :unprocessable_content
    assert_api_error "INVALID_REPORT_RANGE", message: I18n.t("api.errors.invalid_report_range")
    assert response.parsed_body.dig("error", "details", "start_date").present?
  end
end
