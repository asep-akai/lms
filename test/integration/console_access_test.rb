require "test_helper"

class ConsoleAccessTest < ActionDispatch::IntegrationTest
  test "an administrator can enter the console" do
    sign_in admins(:one), scope: :admin
    get console_root_path
    assert_response :success
    assert_select "h1", "Console"
  end

  test "console login form is not cached" do
    get new_admin_session_path

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "meta[name='turbo-cache-control'][content='no-cache']", count: 1
  end

  test "stale console login token returns a fresh form instead of crashing" do
    previous_setting = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post admin_session_path, params: {
      authenticity_token: "stale-token",
      admin: { email: admins(:one).email, password: "password" }
    }

    assert_redirected_to new_admin_session_path
    follow_redirect!
    assert_response :success
    assert_select ".alert-error", "Your session or sign-in form expired. Please try again."
  ensure
    ActionController::Base.allow_forgery_protection = previous_setting
  end

  test "administrator sees each user's organization memberships and roles" do
    second_membership = organizations(:two).memberships.create!(user: users(:one), status: "suspended")
    second_membership.role_ids = [ organizations(:two).roles.find_by!(key: "teacher").id ]
    unassigned_user = User.create!(
      name: "Unassigned User",
      email: "unassigned@example.com",
      password: "password",
      password_confirmation: "password"
    )

    sign_in admins(:one), scope: :admin
    get console_users_path

    assert_response :success
    assert_select "tr", text: /one@example.com/ do
      assert_select "strong", text: organizations(:one).name
      assert_select "strong", text: organizations(:two).name
      assert_select ".badge-active", "Membership active"
      assert_select ".badge-suspended", "Membership suspended"
      assert_select "p", text: /Roles: Organization administrator/
      assert_select "p", text: /Roles: Teacher/
    end
    assert_select "tr", text: /#{Regexp.escape(unassigned_user.email)}/ do
      assert_select "td", text: /No organization memberships/
    end
  end

  test "console role management excludes organization permissions" do
    role = Role.create!(name: "Support administrator", key: "support_admin", organization: nil)
    console_permission = Permission.find_by!(key: "users.index")
    organization_permission = Permission.find_by!(key: "courses.create")

    sign_in admins(:one), scope: :admin
    get edit_console_role_path(role)

    assert_response :success
    assert_select "legend", text: "Users"
    assert_select "legend", text: "Administrators"
    assert_select "legend", text: "Courses", count: 0
    assert_select "input[name='role[permission_ids][]'][value='#{console_permission.id}']"
    Permission::ORGANIZATION_ONLY_KEYS.each do |key|
      permission = Permission.find_by!(key: key)
      assert_select "input[name='role[permission_ids][]'][value='#{permission.id}']", count: 0
    end

    patch console_role_path(role), params: {
      role: {
        name: role.name,
        key: role.key,
        description: role.description,
        permission_ids: [ console_permission.id, organization_permission.id ]
      }
    }

    assert_redirected_to console_roles_path
    assert_equal [ console_permission ], role.permissions.reload
    event = AuditEvent.find_by!(action: "console.role.updated", auditable: role)
    assert_equal(
      { "before" => [], "after" => [ "users.index" ] },
      event.metadata.dig("changes", "permissions")
    )
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

  test "administrator edits an organization through its slug route" do
    organization = organizations(:one)
    sign_in admins(:one), scope: :admin

    get edit_console_organization_path(organization)
    assert_response :success
    assert_select "input[name='organization[name]'][value='#{organization.name}']"

    patch console_organization_path(organization), params: {
      organization: {
        name: "Renamed Organization",
        slug: organization.slug,
        status: organization.status,
        timezone: organization.timezone,
        locale: organization.locale
      }
    }

    assert_redirected_to console_organizations_path
    assert_equal "Renamed Organization", organization.reload.name
    event = AuditEvent.find_by!(action: "console.organization.updated", auditable: organization)
    assert_equal(
      { "before" => "First Organization", "after" => "Renamed Organization" },
      event.metadata.dig("changes", "name")
    )
  end

  test "administrator suspends and reactivates an organization" do
    organization = organizations(:one)
    sign_in admins(:one), scope: :admin

    patch toggle_status_console_organization_path(organization)
    assert_redirected_to console_organizations_path
    assert_equal "suspended", organization.reload.status
    suspended_event = AuditEvent.find_by!(action: "console.organization.suspended", auditable: organization)
    assert_equal({ "before" => "active", "after" => "suspended" }, suspended_event.metadata.dig("changes", "status"))

    get console_organizations_path
    assert_response :success
    assert_select(
      "form[action='#{toggle_status_console_organization_path(organization)}']" \
      "[data-turbo-confirm='Reactivate this organization? Its members will regain access.']",
      text: "Reactivate"
    )

    patch toggle_status_console_organization_path(organization)
    assert_redirected_to console_organizations_path
    assert_predicate organization.reload, :active?
    reactivated_event = AuditEvent.find_by!(action: "console.organization.reactivated", auditable: organization)
    assert_equal({ "before" => "suspended", "after" => "active" }, reactivated_event.metadata.dig("changes", "status"))
  end

  test "administrator creates a user with a chosen temporary password" do
    sign_in admins(:one), scope: :admin

    assert_difference "User.count", 1 do
      post console_users_path, params: {
        user: {
          name: "New Student", email: "new.student@example.com", status: "active",
          password: "temporary-password", password_confirmation: "temporary-password"
        }
      }
    end

    user = User.find_by!(email: "new.student@example.com")
    assert user.valid_password?("temporary-password")
    assert_redirected_to console_users_path
  end

  test "administrator sends a user a password reset link" do
    sign_in admins(:one), scope: :admin
    user = users(:one)

    assert_changes -> { user.reload.reset_password_token } do
      post send_password_reset_console_user_path(user)
    end

    assert_predicate user.reload.reset_password_token, :present?
    assert_redirected_to console_users_path
  end

  test "administrator replaces a user password without knowing the current password" do
    sign_in admins(:one), scope: :admin
    user = users(:one)

    get edit_console_user_path(user)
    assert_response :success
    assert_select "input[type='password'][name='user[password]']", count: 1
    assert_select "input[type='password'][name='user[password]'][value]", count: 0

    patch console_user_path(user), params: {
      user: {
        name: user.name, email: user.email, status: user.status,
        password: "replacement-password", password_confirmation: "replacement-password"
      }
    }

    assert_redirected_to console_users_path
    assert user.reload.valid_password?("replacement-password")
    assert AuditEvent.exists?(action: "console.user.password_changed", auditable: user)
  end

  test "editing a user without a new password preserves the current password" do
    sign_in admins(:one), scope: :admin
    user = users(:one)
    encrypted_password = user.encrypted_password

    patch console_user_path(user), params: {
      user: {
        name: "Updated Name", email: user.email, status: user.status,
        password: "", password_confirmation: ""
      }
    }

    assert_redirected_to console_users_path
    assert_equal encrypted_password, user.reload.encrypted_password
    event = AuditEvent.find_by!(action: "console.user.updated", auditable: user)
    assert_equal(
      { "before" => "Admin User", "after" => "Updated Name" },
      event.metadata.dig("changes", "name")
    )
  end

  test "super administrator creates an administrator with an initial password" do
    sign_in admins(:one), scope: :admin
    role = Role.find_by!(organization: nil, key: "super_admin")

    assert_difference "Admin.count", 1 do
      post console_admins_path, params: {
        admin: {
          name: "New Administrator", email: "new.admin@example.com", status: "active", role_ids: [ role.id ],
          password: "initial-password", password_confirmation: "initial-password"
        }
      }
    end

    admin = Admin.find_by!(email: "new.admin@example.com")
    assert admin.valid_password?("initial-password")
    assert_redirected_to console_admins_path
  end

  test "super administrator replaces an administrator password without seeing the current password" do
    sign_in admins(:one), scope: :admin
    admin = admins(:two)

    get edit_console_admin_path(admin)
    assert_response :success
    assert_select "input[type='password'][name='admin[password]']", count: 1
    assert_select "input[type='password'][name='admin[password]'][value]", count: 0

    patch console_admin_path(admin), params: {
      admin: {
        name: admin.name, email: admin.email, status: admin.status, role_ids: admin.role_ids,
        password: "replacement-password", password_confirmation: "replacement-password"
      }
    }

    assert_redirected_to console_admins_path
    assert admin.reload.valid_password?("replacement-password")
    assert AuditEvent.exists?(action: "console.admin.password_changed", auditable: admin)
  end
end
