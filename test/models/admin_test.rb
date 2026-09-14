require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "console permission is granted through a global role" do
    assert admins(:one).can?("console.access")
  end

  test "suspended administrators cannot authenticate" do
    admins(:one).update!(status: "suspended")
    assert_not admins(:one).active_for_authentication?
  end
end
