require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "key is normalized to lowercase numbers and underscores" do
    role = Role.create!(key: "Customer Service #2!", name: "Customer Service")

    assert_equal "customer_service_2", role.key
  end
end
