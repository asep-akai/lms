require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "system roles are not editable" do
    assert_not organizations(:one).roles.find_by!(key: "admin").editable?
  end


  test "global roles can be assigned only to administrators" do
    assignment = RoleAssignment.new(role: Role.find_by!(key: "super_admin", organization: nil), assignee: users(:one))
    assert_not assignment.valid?
  end

  test "normalizes custom keys" do
    role = organizations(:one).roles.new(name: "Content Editor", key: "Content Editor")
    assert_equal "content_editor", role.key
  end
end
