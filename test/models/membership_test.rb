require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "permission is granted through an assigned role" do
    membership = memberships(:one)
    assert membership.permission?("roles.index")
  end

  test "suspended memberships have no permissions" do
    membership = memberships(:one)
    membership.update!(status: "suspended")
    assert_not membership.permission?("roles.index")
  end

  test "identifies organization administrators by their protected role" do
    assert_predicate memberships(:one), :organization_admin?
    assert_not_predicate memberships(:two), :organization_admin?
  end
end
