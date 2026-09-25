class CreateQuizPages < ActiveRecord::Migration[8.1]
  class MigrationQuiz < ActiveRecord::Base
    self.table_name = "quizzes"
  end

  class MigrationQuizPage < ActiveRecord::Base
    self.table_name = "quiz_pages"
  end

  def up
    create_table :quiz_pages do |t|
      t.references :quiz, null: false, foreign_key: true
      t.string :title, null: false
      t.text :instructions_html
      t.integer :position, null: false, default: 1

      t.timestamps
    end
    add_index :quiz_pages, %i[quiz_id position], unique: true

    add_reference :quiz_questions, :quiz_page, foreign_key: true

    MigrationQuiz.reset_column_information
    MigrationQuizPage.reset_column_information
    MigrationQuiz.find_each do |quiz|
      page = MigrationQuizPage.create!(quiz_id: quiz.id, title: "Page 1", position: 1)
      execute <<~SQL.squish
        UPDATE quiz_questions
        SET quiz_page_id = #{connection.quote(page.id)}
        WHERE quiz_id = #{connection.quote(quiz.id)}
      SQL
    end

    change_column_null :quiz_questions, :quiz_page_id, false
    add_index :quiz_questions, %i[quiz_page_id position]
  end

  def down
    remove_reference :quiz_questions, :quiz_page, foreign_key: true
    drop_table :quiz_pages
  end
end
