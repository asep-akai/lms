class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :organization, null: true, foreign_key: true
      t.references :actor, polymorphic: true, null: true
      t.string :action, null: false
      t.references :auditable, polymorphic: true, null: true
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :audit_events, %i[organization_id occurred_at]
    add_index :audit_events, :action
  end
end
