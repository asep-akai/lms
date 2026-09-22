class AddMeetingUrlToClassMeetings < ActiveRecord::Migration[8.1]
  def change
    add_column :class_meetings, :meeting_url, :string
  end
end
