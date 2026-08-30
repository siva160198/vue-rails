require "test_helper"

class Api::V1::Admin::ApprovalsControllerTest < ActionDispatch::IntegrationTest
  test "a second administrator approves an exact access-change payload before it is applied" do
    previous = ENV["ADMIN_DUAL_CONTROL_ENABLED"]
    ENV["ADMIN_DUAL_CONTROL_ENABLED"] = "true"
    requester = users(:one)
    target = users(:two)
    approver = User.create!(email_address: "approver@example.com", password: "secure-password-value", role: "admin", email_verified_at: Time.current)
    sign_in_as requester

    patch api_v1_admin_user_url(target), params: { role: "editor", active: true }, as: :json
    assert_response :conflict
    assert_api_error("SECOND_ADMIN_APPROVAL_REQUIRED")
    approval = AdminApproval.last
    assert_equal requester, approval.requester

    sign_in_as approver
    get api_v1_admin_approvals_url, as: :json
    assert_response :success
    assert_equal approval.id, response.parsed_body.dig("approvals", 0, "id")
    patch api_v1_admin_approval_url(approval), headers: { "X-Step-Up-Token" => step_up_token_for(approver, "admin_approval") }, as: :json
    assert_response :success

    sign_in_as requester
    patch api_v1_admin_user_url(target), params: { role: "editor", active: true }, headers: { "X-Step-Up-Token" => step_up_token_for(requester, "admin_user_update") }, as: :json
    assert_response :success
    assert_equal "editor", target.reload.role
    assert approval.reload.consumed_at
  ensure
    ENV["ADMIN_DUAL_CONTROL_ENABLED"] = previous
  end

  test "requester cannot approve their own change" do
    approval = AdminApproval.create!(requester: users(:one), action_key: "admin.test", payload_digest: "digest", expires_at: 10.minutes.from_now)
    sign_in_as users(:one)
    patch api_v1_admin_approval_url(approval), headers: { "X-Step-Up-Token" => step_up_token_for(users(:one), "admin_approval") }, as: :json
    assert_response :forbidden
  end
end
