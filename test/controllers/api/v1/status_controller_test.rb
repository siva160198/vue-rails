require "test_helper"

class Api::V1::StatusControllerTest < ActionDispatch::IntegrationTest
  test "returns the API and database status as JSON" do
    get api_v1_status_url

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal "ok", response.parsed_body["status"]
    assert_equal "PostgreSQL", response.parsed_body.dig("database", "adapter")
  end
end
