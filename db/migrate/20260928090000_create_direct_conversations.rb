class CreateDirectConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :direct_conversations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :participant_one_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :participant_two_membership, null: false, foreign_key: { to_table: :memberships }
      t.datetime :last_message_at

      t.timestamps
    end

    add_index :direct_conversations,
      %i[organization_id participant_one_membership_id participant_two_membership_id],
      unique: true,
      name: "index_direct_conversations_on_participants"
    add_check_constraint :direct_conversations,
      "participant_one_membership_id < participant_two_membership_id",
      name: "direct_conversations_canonical_participant_order"

    create_table :direct_messages do |t|
      t.references :direct_conversation, null: false, foreign_key: true
      t.references :sender_membership, null: false, foreign_key: { to_table: :memberships }
      t.text :body, null: false

      t.timestamps
    end

    add_index :direct_messages, %i[direct_conversation_id created_at]
  end
end
