class RbacSeeder
  APP_ADMIN_PERMISSIONS = %w[
    organization.update
    memberships.index memberships.create memberships.update memberships.destroy
    roles.index roles.create roles.update roles.destroy
    audit_events.index
  ].freeze

  def self.call!
    Permission::CATALOG.each do |key, (name, description)|
      Permission.find_or_initialize_by(key: key).tap do |permission|
        permission.update!(name: name, description: description)
      end
    end
  end

  def self.provision_console_role!
    call!
    Role.find_or_initialize_by(organization: nil, key: "super_admin").tap do |role|
      role.update!(name: "Super administrator", description: "Full platform console access.", system: true)
      role.permissions = Permission.where(key: Permission::CATALOG.keys)
    end
  end
end
