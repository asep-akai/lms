class CreateRoleAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :role_assignments do |t|
      t.references :role, null: false, foreign_key: true
      t.references :assignee, polymorphic: true, null: false

      t.timestamps
    end

    add_index :role_assignments, %i[role_id assignee_type assignee_id], unique: true, name: "index_role_assignments_uniqueness"
  end
end
