require "test_helper"

class RecoverySweepTest < ActiveSupport::TestCase
  test "removes assignments whose scope no longer matches the assignee" do
    role = Role.find_by!(organization: nil, key: "super_admin")
    now = Time.current
    RoleAssignment.insert_all!([ {
      role_id: role.id,
      assignee_type: "User",
      assignee_id: users(:one).id,
      created_at: now,
      updated_at: now
    } ])

    assert_difference "RoleAssignment.count", -1 do
      assert_equal 1, RecoverySweep.call!
    end
  end
end
