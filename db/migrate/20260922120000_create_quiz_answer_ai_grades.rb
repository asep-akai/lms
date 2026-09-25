class CreateQuizAnswerAiGrades < ActiveRecord::Migration[8.1]
  def change
    create_table :quiz_answer_ai_grades do |t|
      t.references :quiz_attempt, null: false, foreign_key: true
      t.references :quiz_question, null: false, foreign_key: true
      t.boolean :correct, null: false
      t.text :rationale, null: false
      t.string :model, null: false

      t.timestamps
    end

    add_index :quiz_answer_ai_grades, [ :quiz_attempt_id, :quiz_question_id ], unique: true, name: "index_quiz_answer_ai_grades_on_attempt_and_question"
  end
end
