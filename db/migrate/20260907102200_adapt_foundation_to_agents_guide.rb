class AdaptFoundationToAgentsGuide < ActiveRecord::Migration[8.1]
  def up
    adapt_users
    adapt_roles
    adapt_audit_events
    migrate_role_assignments
    drop_table :membership_roles, if_exists: true
    drop_table :sessions, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private
    def adapt_users
      rename_column :users, :email_address, :email if column_exists?(:users, :email_address)
      rename_column :users, :password_digest, :encrypted_password if column_exists?(:users, :password_digest)
      remove_column :users, :platform_admin if column_exists?(:users, :platform_admin)

      add_column :users, :reset_password_token, :string unless column_exists?(:users, :reset_password_token)
      add_column :users, :reset_password_sent_at, :datetime unless column_exists?(:users, :reset_password_sent_at)
      add_column :users, :remember_created_at, :datetime unless column_exists?(:users, :remember_created_at)
      add_column :users, :invited_at, :datetime unless column_exists?(:users, :invited_at)

      add_index :users, :email, unique: true unless index_exists?(:users, :email, unique: true)
      add_index :users, :reset_password_token, unique: true unless index_exists?(:users, :reset_password_token, unique: true)
    end

    def adapt_roles
      change_column_null :roles, :organization_id, true
      add_index :roles, :key, unique: true, where: "organization_id IS NULL", name: "index_global_roles_on_key" unless index_exists?(:roles, :key, name: "index_global_roles_on_key")
    end

    def adapt_audit_events
      remove_foreign_key :audit_events, :users if foreign_key_exists?(:audit_events, :users)
      unless column_exists?(:audit_events, :actor_type)
        add_column :audit_events, :actor_type, :string
        execute "UPDATE audit_events SET actor_type = 'User' WHERE actor_id IS NOT NULL"
        add_index :audit_events, %i[actor_type actor_id]
      end
    end

    def migrate_role_assignments
      return unless table_exists?(:membership_roles)

      execute <<~SQL.squish
        INSERT INTO role_assignments (role_id, assignee_type, assignee_id, created_at, updated_at)
        SELECT membership_roles.role_id, 'User', memberships.user_id,
               membership_roles.created_at, membership_roles.updated_at
        FROM membership_roles
        INNER JOIN memberships ON memberships.id = membership_roles.membership_id
        ON CONFLICT DO NOTHING
      SQL
    end
end
