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

  test "user listing uses bounded forward and backward keyset cursors" do
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
      params: { per_page: 999, sort: "not_allowed", direction: "sideways" }, as: :json

    assert_response :success
    first_page_ids = response.parsed_body["users"].pluck("id")
    pagination = response.parsed_body.fetch("pagination")
    assert_equal 50, first_page_ids.size
    assert pagination.fetch("has_next")
    assert_not pagination.fetch("has_previous")
    assert_nil pagination.fetch("total")

    get api_v1_admin_users_url, params: { per_page: 50, cursor: pagination.fetch("next_cursor") }, as: :json
    assert_response :success
    assert_equal 5, response.parsed_body["users"].size
    assert response.parsed_body.dig("pagination", "has_previous")
    previous_cursor = response.parsed_body.dig("pagination", "previous_cursor")

    get api_v1_admin_users_url, params: { per_page: 50, cursor: previous_cursor }, as: :json
    assert_response :success
    assert_equal first_page_ids, response.parsed_body["users"].pluck("id")
  end

  test "user search escapes SQL wildcard characters" do
    User.create!(email_address: "percent%user@example.com", password: "a-secure-password", role: "member")
    sign_in_as users(:one)

    get api_v1_admin_users_url, params: { search: "%", include_total: true }, as: :json

    assert_response :success
    assert_equal [ "percent%user@example.com" ], response.parsed_body["users"].pluck("email_address")
    assert_equal 1, response.parsed_body.dig("pagination", "total")
  end

  test "rejects a cursor when its search context changes" do
    4.times { |index| User.create!(email_address: "cursor_#{index}@example.com", password: "a-secure-password", role: "member") }
    sign_in_as users(:one)
    get api_v1_admin_users_url, params: { per_page: 5 }, as: :json
    cursor = response.parsed_body.dig("pagination", "next_cursor")

    get api_v1_admin_users_url, params: { per_page: 5, cursor: cursor, search: "changed" }, as: :json
    assert_response :bad_request
    assert_api_error("INVALID_PAGINATION_CURSOR")
  end

  test "cursor traversal handles nullable sort values" do
    5.times do |index|
      User.create!(email_address: "nullable_#{index}@example.com", password: "a-secure-password", role: "member", email_verified_at: nil)
    end
    sign_in_as users(:one)

    get api_v1_admin_users_url, params: { per_page: 5, sort: "email_verified_at", direction: "asc" }, as: :json
    first_ids = response.parsed_body["users"].pluck("id")
    cursor = response.parsed_body.dig("pagination", "next_cursor")
    get api_v1_admin_users_url, params: { per_page: 5, sort: "email_verified_at", direction: "asc", cursor: cursor }, as: :json

    assert_response :success
    assert_empty first_ids & response.parsed_body["users"].pluck("id")
    previous = response.parsed_body.dig("pagination", "previous_cursor")
    get api_v1_admin_users_url, params: { per_page: 5, sort: "email_verified_at", direction: "asc", cursor: previous }, as: :json
    assert_equal first_ids, response.parsed_body["users"].pluck("id")
  end

  test "admin updates another user and records an audit log" do
    sign_in_as users(:one)
    target = users(:two)

    assert_difference("AuditLog.count", 1) do
      patch api_v1_admin_user_url(target), params: { role: "admin", active: false }, headers: { "X-Step-Up-Token" => step_up_token_for(users(:one), "admin_user_update") }, as: :json
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

  test "invalid role error uses the role form field key" do
    sign_in_as users(:one)

    patch api_v1_admin_user_url(users(:two)), params: { role: "missing_role" }, as: :json

    assert_response :unprocessable_content
    assert_equal [ "tidak tersedia" ], response.parsed_body.dig("error", "details", "role")
    assert_nil response.parsed_body.dig("error", "details", "role_record")
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
