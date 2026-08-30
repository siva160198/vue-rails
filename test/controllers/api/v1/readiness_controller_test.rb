require "test_helper"

class Api::V1::ReadinessControllerTest < ActionDispatch::IntegrationTest
  test "reports database dependencies as ready" do
    get api_v1_readiness_url, as: :json

    assert_response :success
    assert_equal "ready", response.parsed_body.fetch("status")
    assert_equal({ "status" => "ready" }, response.parsed_body)
  end

  test "returns the standard error contract when a dependency is unavailable" do
    original_connection = SolidQueue::Record.method(:connection)
    SolidQueue::Record.define_singleton_method(:connection) { raise ActiveRecord::ConnectionNotEstablished }

    get api_v1_readiness_url, as: :json

    assert_response :service_unavailable
    assert_api_error "SERVICE_UNAVAILABLE"
    assert_empty response.parsed_body.dig("error", "details")
  ensure
    SolidQueue::Record.define_singleton_method(:connection, original_connection)
  end
end
