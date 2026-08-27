require "test_helper"

class Api::V1::Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "admin lists users" do
    sign_in_as users(:one)

    get api_v1_admin_users_url, as: :json

    assert_response :success
    assert_equal 2, response.parsed_body["users"].size
  end

  test "admin updates another user and records an audit log" do
    sign_in_as users(:one)
    target = users(:two)

    assert_difference("AuditLog.count", 1) do
      patch api_v1_admin_user_url(target), params: { role: "admin", active: false }, as: :json
    end

    assert_response :success
    assert target.reload.admin?
    assert_not target.active?
    assert_equal "admin.user_updated", AuditLog.last.action
    assert_equal users(:one), AuditLog.last.actor
  end

  test "admin cannot update their own access" do
    sign_in_as users(:one)

    patch api_v1_admin_user_url(users(:one)), params: { role: "member" }, as: :json

    assert_response :forbidden
    assert users(:one).reload.admin?
  end

  test "member cannot list users or audit logs" do
    sign_in_as users(:two)

    get api_v1_admin_users_url, as: :json
    assert_response :forbidden

    get api_v1_admin_audit_logs_url, as: :json
    assert_response :forbidden
  end

  test "admin lists audit logs" do
    actor = users(:one)
    AuditLog.record!(action: "test.event", actor: actor, auditable: users(:two))
    sign_in_as actor

    get api_v1_admin_audit_logs_url, as: :json

    assert_response :success
    assert_equal "test.event", response.parsed_body.dig("audit_logs", 0, "action")
    assert_equal actor.email_address, response.parsed_body.dig("audit_logs", 0, "actor_email")
  end

  test "role with view permission cannot update users without update permission" do
    roles(:editor).permissions << permissions(:users_view)
    viewer = users(:two)
    viewer.update!(role: roles(:editor).key)
    sign_in_as viewer

    get api_v1_admin_users_url, as: :json
    assert_response :success

    patch api_v1_admin_user_url(users(:one)), params: { active: false }, as: :json
    assert_response :forbidden
    assert users(:one).reload.active?
  end
end
