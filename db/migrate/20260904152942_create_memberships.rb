class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :memberships, %i[organization_id user_id], unique: true
    add_index :memberships, %i[organization_id status]
  end
end
