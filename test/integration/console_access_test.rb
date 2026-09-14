require "test_helper"

class ConsoleAccessTest < ActionDispatch::IntegrationTest
  test "an administrator can enter the console" do
    sign_in admins(:one), scope: :admin
    get console_root_path
    assert_response :success
    assert_select "h1", "Console"
  end

  test "an application user cannot enter the console" do
    sign_in users(:one)
    get console_root_path
    assert_redirected_to new_admin_session_path
  end

  test "administrator provisions an organization for an existing owner" do
    sign_in admins(:one), scope: :admin

    assert_difference [ "Organization.count", "Membership.count" ], 1 do
      post console_organizations_path, params: {
        organization: {
          name: "Provisioned School", slug: "provisioned-school", timezone: "UTC", locale: "en",
          owner_email: users(:one).email
        }
      }
    end

    organization = Organization.find_by!(slug: "provisioned-school")
    assert_redirected_to console_organizations_path
    assert_equal %w[admin student teacher], organization.roles.order(:key).pluck(:key)
  end
end
