class CreateSupportTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :support_tickets do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :reporter_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :escalated_by_membership, foreign_key: { to_table: :memberships }
      t.string :subject, null: false
      t.string :category, null: false, default: "technical_issue"
      t.string :priority, null: false, default: "normal"
      t.string :status, null: false, default: "open"
      t.datetime :escalated_at
      t.timestamps
    end

    add_index :support_tickets, %i[organization_id status]
    add_index :support_tickets, :escalated_at

    create_table :support_messages do |t|
      t.references :support_ticket, null: false, foreign_key: true
      t.references :author, polymorphic: true, null: false
      t.text :body, null: false
      t.timestamps
    end
  end
end
