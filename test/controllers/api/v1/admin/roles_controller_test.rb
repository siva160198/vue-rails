require "test_helper"

class Api::V1::Admin::RolesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "admin can list roles" do
    get api_v1_admin_roles_url
    assert_response :success
    assert_includes response.parsed_body.fetch("roles").pluck("key"), "admin"
  end

  test "admin can create, update, and delete an unused custom role" do
    assert_difference("Role.count", 1) do
      post api_v1_admin_roles_url, params: { key: "support_agent", name: "Support", description: "Membantu pengguna" }, as: :json
    end
    assert_response :created
    role = Role.find_by!(key: "support_agent")

    patch api_v1_admin_role_url(role), params: { name: "Support Agent" }, as: :json
    assert_response :success
    assert_equal "Support Agent", role.reload.name

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
end
