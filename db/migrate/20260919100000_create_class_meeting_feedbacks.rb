class CreateClassMeetingFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :class_meeting_feedbacks do |t|
      t.references :class_meeting, null: false, foreign_key: true
      t.references :author_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :author_role, null: false
      t.integer :rating, null: false
      t.text :comment
      t.text :internal_feedback
      t.text :feedback_to_student
      t.text :topics_discussed
      t.text :next_topics

      t.timestamps
    end

    add_index :class_meeting_feedbacks,
      %i[class_meeting_id author_membership_id],
      unique: true,
      name: "index_class_feedbacks_on_meeting_and_author"
    add_check_constraint :class_meeting_feedbacks,
      "rating BETWEEN 1 AND 5",
      name: "class_meeting_feedbacks_rating_range"
    add_check_constraint :class_meeting_feedbacks,
      "author_role IN ('teacher', 'student')",
      name: "class_meeting_feedbacks_author_role"
  end
end
