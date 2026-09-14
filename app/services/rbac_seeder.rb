class RbacSeeder
  def self.call!
    Permission::CATALOG.each do |key, (name, description)|
      Permission.find_or_initialize_by(key: key).tap do |permission|
        permission.update!(name: name, description: description)
      end
    end

    sync_organization_admin_roles!
  end

  def self.provision_console_role!
    call!
    Role.find_or_initialize_by(organization: nil, key: "super_admin").tap do |role|
      role.update!(name: "Super administrator", description: "Full platform console access.", system: true)
      role.permissions = Permission.console_assignable
    end
  end

  def self.sync_organization_admin_roles!
    permissions = Permission.organization_assignable
    Role.where.not(organization_id: nil).where(key: "admin").find_each do |role|
      role.permissions = permissions
    end
  end
end
