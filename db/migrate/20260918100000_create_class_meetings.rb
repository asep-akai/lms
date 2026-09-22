class CreateClassMeetings < ActiveRecord::Migration[8.1]
  def change
    create_table :class_meetings do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :teacher_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :subject, null: false
      t.string :subject_key, null: false
      t.string :topic, null: false
      t.datetime :starts_at, null: false
      t.string :delivery_mode, null: false
      t.integer :meeting_number, null: false
      t.timestamps
    end
    add_index :class_meetings, %i[organization_id subject_key meeting_number], unique: true, name: "index_class_meetings_on_subject_sequence"

    create_table :class_meeting_students do |t|
      t.references :class_meeting, null: false, foreign_key: true
      t.references :membership, null: false, foreign_key: true
      t.timestamps
    end
    add_index :class_meeting_students, %i[class_meeting_id membership_id], unique: true, name: "index_class_meeting_students_on_meeting_and_membership"
  end
end
