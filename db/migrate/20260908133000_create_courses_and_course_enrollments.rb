class CreateCoursesAndCourseEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :courses, [ :organization_id, :name ]

    create_table :course_enrollments do |t|
      t.references :course, null: false, foreign_key: true
      t.references :membership, null: false, foreign_key: true

      t.timestamps
    end

    add_index :course_enrollments, [ :course_id, :membership_id ], unique: true
  end
end
