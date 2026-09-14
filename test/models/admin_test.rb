require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "console permission is granted through a global role" do
    assert admins(:one).can?("console.access")
  end

  test "organization-only permissions are never granted to console administrators" do
    role = Role.create!(name: "Legacy mixed role", key: "legacy_mixed", organization: nil)
    role.permissions = [ Permission.find_by!(key: "courses.create") ]
    admins(:one).role_assignments.create!(role: role)

    assert_not admins(:one).can?("courses.create")
  end

  test "suspended administrators cannot authenticate" do
    admins(:one).update!(status: "suspended")
    assert_not admins(:one).active_for_authentication?
  end
end
