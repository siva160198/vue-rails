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
      params: { search: "198.51.100.42", page: "invalid", per_page: 1 }, as: :json

    assert_response :success
    assert_equal [ "security.reviewed" ], response.parsed_body["audit_logs"].pluck("action")
    assert_equal(
      { "page" => 1, "per_page" => 5, "total" => 1, "total_pages" => 1 },
      response.parsed_body["pagination"]
    )
  end
end
