class SyncOrganizationAdminRolePermissions < ActiveRecord::Migration[8.1]
  ORGANIZATION_PERMISSION_KEYS = %w[
    organization.update
    memberships.index memberships.create memberships.update memberships.destroy
    courses.index courses.create courses.update courses.destroy course_enrollments.update
    roles.index roles.create roles.update roles.destroy
    audit_events.index
  ].freeze

  CONSOLE_PERMISSION_KEYS = %w[
    console.access
    organizations.index organizations.create organizations.update
    users.index users.create users.update users.destroy
    admins.index admins.create admins.update admins.destroy
  ].freeze

  def up
    execute <<~SQL.squish
      DELETE FROM role_permissions
      USING roles, permissions
      WHERE role_permissions.role_id = roles.id
        AND role_permissions.permission_id = permissions.id
        AND roles.organization_id IS NOT NULL
        AND roles.key = 'admin'
        AND permissions.key IN (#{quoted_keys(CONSOLE_PERMISSION_KEYS)})
    SQL

    execute <<~SQL.squish
      INSERT INTO role_permissions (role_id, permission_id, created_at, updated_at)
      SELECT roles.id, permissions.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM roles
      CROSS JOIN permissions
      WHERE roles.organization_id IS NOT NULL
        AND roles.key = 'admin'
        AND permissions.key IN (#{quoted_keys(ORGANIZATION_PERMISSION_KEYS)})
      ON CONFLICT (role_id, permission_id) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private
    def quoted_keys(keys)
      keys.map { |key| connection.quote(key) }.join(", ")
    end
end
