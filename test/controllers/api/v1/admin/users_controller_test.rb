require "test_helper"

class Api::V1::Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "admin lists users" do
    sign_in_as users(:one)

    get api_v1_admin_users_url, as: :json

    assert_response :success
    assert_equal 2, response.parsed_body["users"].size
  end

  test "admin lazily loads one user with role options for the edit modal" do
    sign_in_as users(:one)

    get api_v1_admin_user_url(users(:two)), as: :json

    assert_response :success
    assert_equal users(:two).email_address, response.parsed_body.dig("user", "email_address")
    assert_includes response.parsed_body.fetch("roles").pluck("key"), "admin"
  end

  test "user listing validates pagination and caps each server response" do
    now = Time.current
    User.insert_all!(53.times.map do |index|
      {
        email_address: "paginated_#{index}@example.com",
        password_digest: users(:two).password_digest,
        role: "member",
        active: true,
        created_at: now + index.seconds,
        updated_at: now + index.seconds
      }
    end)
    sign_in_as users(:one)

    get api_v1_admin_users_url,
      params: { page: 999, per_page: 999, sort: "not_allowed", direction: "sideways" }, as: :json

    assert_response :success
    assert_equal 5, response.parsed_body["users"].size
    assert_equal({ "page" => 2, "per_page" => 50, "total" => 55, "total_pages" => 2 }, response.parsed_body["pagination"])
  end

  test "user search escapes SQL wildcard characters" do
    User.create!(email_address: "percent%user@example.com", password: "a-secure-password", role: "member")
    sign_in_as users(:one)

    get api_v1_admin_users_url, params: { search: "%" }, as: :json

    assert_response :success
    assert_equal [ "percent%user@example.com" ], response.parsed_body["users"].pluck("email_address")
    assert_equal 1, response.parsed_body.dig("pagination", "total")
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

  test "unchanged user update skips persistence and audit log" do
    sign_in_as users(:one)
    target = users(:two)

    assert_no_changes(-> { target.reload.updated_at }) do
      assert_no_difference("AuditLog.count") do
        patch api_v1_admin_user_url(target), params: { role: target.role, active: target.active }, as: :json
      end
    end

    assert_response :success
    assert response.parsed_body["unchanged"]
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

    get api_v1_admin_user_url(users(:one)), as: :json
    assert_response :success

    patch api_v1_admin_user_url(users(:one)), params: { active: false }, as: :json
    assert_response :forbidden
    assert users(:one).reload.active?
  end
end
