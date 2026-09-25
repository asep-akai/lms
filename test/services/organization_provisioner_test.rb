require "test_helper"

class OrganizationProvisionerTest < ActiveSupport::TestCase
  test "creates protected defaults and grants the owner admin access" do
    owner = users(:one)
    organization = Organization.new(name: "New School", slug: "new-school", timezone: "Jakarta", locale: "en")

    OrganizationProvisioner.call!(organization: organization, owner: owner)

    assert_equal %w[admin student teacher], organization.roles.order(:key).pluck(:key)
    assert organization.roles.find_by!(key: "admin").system?
    assert organization.memberships.find_by!(user: owner).permission?("memberships.create")
    assert_equal "organization.created", organization.audit_events.last.action
  end
end
