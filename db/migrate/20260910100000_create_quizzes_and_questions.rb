class CreateQuizzesAndQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :quizzes do |t|
      t.references :course, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description

      t.timestamps
    end
    add_index :quizzes, [ :course_id, :title ]

    create_table :quiz_questions do |t|
      t.references :quiz, null: false, foreign_key: true
      t.string :question_type, null: false
      t.text :content_html, null: false
      t.string :short_answer
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :quiz_questions, [ :quiz_id, :position ]

    create_table :quiz_answer_options do |t|
      t.references :quiz_question, null: false, foreign_key: true
      t.text :content, null: false
      t.boolean :correct, null: false, default: false

      t.timestamps
    end
  end
end
