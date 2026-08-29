require "test_helper"

class Api::V1::Admin::RolesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "admin can list roles" do
    get api_v1_admin_roles_url
    assert_response :success
    assert_includes response.parsed_body.fetch("roles").pluck("key"), "admin"
    assert_equal %w[page per_page total total_pages], response.parsed_body.fetch("pagination").keys.sort
  end

  test "admin lazily loads one role with permissions for the edit modal" do
    get api_v1_admin_role_url(roles(:editor)), as: :json

    assert_response :success
    assert_equal roles(:editor).key, response.parsed_body.dig("role", "key")
    assert_includes response.parsed_body.fetch("permissions").pluck("key"), "roles.view"
  end

  test "admin can create, update, and delete an unused custom role" do
    assert_difference("Role.count", 1) do
      post api_v1_admin_roles_url, params: { key: "support_agent", name: "Support", description: "Membantu pengguna", permission_keys: [ "users.view" ] }, as: :json
    end
    assert_response :created
    role = Role.find_by!(key: "support_agent")
    assert_equal [ "users.view" ], role.permission_keys

    patch api_v1_admin_role_url(role), params: { name: "Support Agent", permission_keys: %w[users.view users.update] }, as: :json
    assert_response :success
    assert_equal "Support Agent", role.reload.name
    assert_equal %w[users.update users.view], role.permission_keys

    assert_difference("Role.count", -1) { delete api_v1_admin_role_url(role) }
    assert_response :no_content
  end

  test "system and used roles cannot be deleted" do
    delete api_v1_admin_role_url(roles(:admin))
    assert_response :forbidden

    users(:two).update!(role: roles(:editor).key)
    delete api_v1_admin_role_url(roles(:editor))
    assert_response :forbidden
  end

  test "unchanged role update skips persistence and audit log" do
    role = roles(:editor)
    assert_no_changes(-> { role.reload.updated_at }) do
      assert_no_difference("AuditLog.count") do
        patch api_v1_admin_role_url(role), params: { name: role.name, description: role.description, permission_keys: role.permission_keys }, as: :json
      end
    end

    assert_response :success
    assert response.parsed_body["unchanged"]
  end

  test "role mutations require their matching granular permission" do
    actor = users(:two)
    actor.update!(role: roles(:editor).key)
    target = Role.create!(key: "temporary_role", name: "Temporary")

    roles(:editor).permissions = [ permissions(:roles_view) ]
    sign_in_as actor
    post api_v1_admin_roles_url, params: { key: "blocked_role", name: "Blocked" }, as: :json
    assert_response :forbidden
    patch api_v1_admin_role_url(target), params: { name: "Blocked update" }, as: :json
    assert_response :forbidden
    delete api_v1_admin_role_url(target), as: :json
    assert_response :forbidden

    roles(:editor).permissions = [ permissions(:roles_view), permissions(:roles_create) ]
    post api_v1_admin_roles_url, params: { key: "allowed_role", name: "Allowed" }, as: :json
    assert_response :created

    roles(:editor).permissions = [ permissions(:roles_view), permissions(:roles_update) ]
    patch api_v1_admin_role_url(target), params: { name: "Updated" }, as: :json
    assert_response :success

    roles(:editor).permissions = [ permissions(:roles_view), permissions(:roles_delete) ]
    delete api_v1_admin_role_url(target), as: :json
    assert_response :no_content
  end
end
