require "test_helper"

class Api::V1::Admin::AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "audit log listing uses reusable search and pagination metadata" do
    AuditLog.record!(
      action: "security.reviewed",
      actor: users(:one),
      auditable: users(:two),
      request: Struct.new(:remote_ip, :user_agent).new("198.51.100.42", "Test")
    )

    get api_v1_admin_audit_logs_url,
      params: { search: "198.51.100.42", per_page: 1, include_total: true }, as: :json

    assert_response :success
    assert_equal [ "security.reviewed" ], response.parsed_body["audit_logs"].pluck("action")
    assert_equal(
      { "per_page" => 5, "next_cursor" => nil, "previous_cursor" => nil, "has_next" => false, "has_previous" => false, "total" => 1 },
      response.parsed_body["pagination"]
    )
  end
end
