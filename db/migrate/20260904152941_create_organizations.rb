class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, null: false, default: "active"
      t.string :timezone, null: false, default: "UTC"
      t.string :locale, null: false, default: "en"

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
    add_index :organizations, :status
  end
end
