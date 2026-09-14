require "test_helper"

class RolePermissionTest < ActiveSupport::TestCase
  test "does not duplicate a permission within a role" do
    role = organizations(:one).roles.find_by!(key: "admin")
    duplicate = RolePermission.new(role: role, permission: role.permissions.first)
    assert_not duplicate.valid?
  end
end
