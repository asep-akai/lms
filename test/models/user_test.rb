require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email" do
    user = User.new(email: " DOWNCASED@EXAMPLE.COM ", name: "User", password: "password")
    assert_equal("downcased@example.com", user.email)
  end

  test "suspended users are not active" do
    users(:one).update!(status: "suspended")
    assert_not users(:one).active?
  end

  test "does not gain console access from organization roles" do
    assert_not users(:one).can?("console.access", organization: organizations(:one))
  end

  test "identifies active organization administrators" do
    assert users(:one).organization_admin?(organizations(:one))
    assert_not users(:two).organization_admin?(organizations(:two))
  end
end
