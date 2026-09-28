class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :recipient_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :actor_membership, foreign_key: { to_table: :memberships }
      t.references :notifiable, polymorphic: true
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body
      t.string :path, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, %i[recipient_membership_id read_at created_at], name: "index_notifications_on_recipient_read_and_created"
  end
end
