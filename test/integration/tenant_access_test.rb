require "test_helper"

class TenantAccessTest < ActionDispatch::IntegrationTest
  test "organization administrator can manage roles" do
    sign_in users(:one)
    get organization_roles_path(organizations(:one))
    assert_response :success
    assert_select "h1", "Roles"
  end

  test "dashboard contains only the signed-in user's organizations" do
    sign_in users(:one)
    get root_path
    assert_response :success
    assert_select "h2", text: organizations(:one).name
    assert_select "h2", text: organizations(:two).name, count: 0
  end

  test "member cannot access another organization" do
    sign_in users(:one)
    get organization_memberships_path(organizations(:two))
    assert_redirected_to root_path
  end

  test "member without permission cannot manage roles" do
    sign_in users(:two)
    get organization_roles_path(organizations(:two))
    assert_redirected_to root_path
  end

  test "role form can render inside the modal frame" do
    sign_in users(:one)
    get new_organization_role_path(organizations(:one), modal: 1), headers: { "Turbo-Frame" => "modal" }
    assert_response :success
    assert_includes response.body, '<turbo-frame id="modal">'
    assert_not_includes response.body, "<!DOCTYPE html>"
  end

  test "organization administrator can invite a new member" do
    sign_in users(:one)
    role = organizations(:one).roles.find_by!(key: "teacher")

    assert_difference [ "User.count", "Membership.count" ], 1 do
      post organization_memberships_path(organizations(:one)), params: {
        membership: { name: "Invited Teacher", email: "teacher@example.com", role_ids: [ role.id ] }
      }
    end

    assert_redirected_to organization_memberships_path(organizations(:one))
    assert User.find_by!(email: "teacher@example.com").invited_at.present?
  end

  test "organization cannot lose its final active administrator" do
    sign_in users(:one)
    membership = memberships(:one)
    admin_role = organizations(:one).roles.find_by!(key: "admin")

    patch organization_membership_path(organizations(:one), membership), params: {
      membership: { status: "suspended", role_ids: [ admin_role.id ] }
    }

    assert_response :unprocessable_entity
    assert membership.reload.active?
  end
end
