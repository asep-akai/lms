class CreateCourseSections < ActiveRecord::Migration[8.1]
  class MigrationCourse < ActiveRecord::Base
    self.table_name = "courses"
  end

  class MigrationSection < ActiveRecord::Base
    self.table_name = "course_sections"
  end

  class MigrationContent < ActiveRecord::Base
    self.table_name = "course_contents"
  end

  def up
    create_table :course_sections do |t|
      t.references :course, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_index :course_sections, %i[course_id position], unique: true

    add_reference :course_contents, :course_section, foreign_key: true
    MigrationCourse.find_each do |course|
      section = MigrationSection.create!(course_id: course.id, name: "Course content", position: 1)
      MigrationContent.where(course_id: course.id).update_all(course_section_id: section.id)
    end
    change_column_null :course_contents, :course_section_id, false

    remove_index :course_contents, name: "index_course_contents_on_course_id_and_position"
    add_index :course_contents, %i[course_section_id position], unique: true
  end

  def down
    remove_index :course_contents, name: "index_course_contents_on_course_section_id_and_position"
    add_index :course_contents, %i[course_id position]
    remove_reference :course_contents, :course_section, foreign_key: true
    drop_table :course_sections
  end
end
