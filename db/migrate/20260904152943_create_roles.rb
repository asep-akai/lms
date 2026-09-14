class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.references :organization, null: true, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.text :description
      t.boolean :system, null: false, default: false

      t.timestamps
    end

    add_index :roles, %i[organization_id key], unique: true
    add_index :roles, :key, unique: true, where: "organization_id IS NULL", name: "index_global_roles_on_key"
  end
end
