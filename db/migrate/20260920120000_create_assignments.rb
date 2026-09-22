class CreateAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :assignments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :teacher_membership, null: false, foreign_key: { to_table: :memberships }
      t.string :title, null: false
      t.text :description, null: false
      t.datetime :deadline, null: false

      t.timestamps
    end

    create_table :assignment_recipients do |t|
      t.references :assignment, null: false, foreign_key: true
      t.references :student_membership, null: false, foreign_key: { to_table: :memberships }

      t.timestamps
    end
    add_index :assignment_recipients, %i[assignment_id student_membership_id], unique: true

    create_table :assignment_submissions do |t|
      t.references :assignment_recipient, null: false, foreign_key: true, index: { unique: true }
      t.text :body
      t.datetime :submitted_at
      t.text :teacher_comment
      t.datetime :commented_at

      t.timestamps
    end
  end
end
