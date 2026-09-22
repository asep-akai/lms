module TestRbac
  module_function

  def seed!
    console_role = RbacSeeder.provision_console_role!
    Admin.find_each { |admin| admin.role_assignments.find_or_create_by!(role: console_role) }

    Organization.find_each do |organization|
      roles = OrganizationProvisioner::DEFAULT_ROLES.to_h do |key, name|
        role = organization.roles.find_or_initialize_by(key: key)
        role.update!(name: name, system: true)
        [ key, role ]
      end
      roles.fetch("admin").permissions = Permission.organization_assignable
      roles.fetch("teacher").permissions = Permission.where(key: RbacSeeder::TEACHER_PERMISSION_KEYS)

      organization.memberships.includes(:user).find_each do |membership|
        key = membership.user.email == "one@example.com" ? "admin" : "student"
        membership.role_ids = [ roles.fetch(key).id ]
      end
    end
  end
end
