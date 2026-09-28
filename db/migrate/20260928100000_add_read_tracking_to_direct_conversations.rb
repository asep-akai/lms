class AddReadTrackingToDirectConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :direct_conversations, :participant_one_last_read_at, :datetime
    add_column :direct_conversations, :participant_two_last_read_at, :datetime
  end
end
