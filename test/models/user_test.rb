require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "recovery code can only be consumed once" do
    user = users(:one)
    code = user.regenerate_recovery_codes!.first

    assert user.consume_recovery_code(code)
    assert_not user.consume_recovery_code(code)
  end
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end
end
