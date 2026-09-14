class CreateQuizAnswerOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :quiz_answer_overrides do |t|
      t.references :quiz_attempt, null: false, foreign_key: true
      t.references :quiz_question, null: false, foreign_key: true
      t.boolean :correct, null: false

      t.timestamps
    end

    add_index :quiz_answer_overrides, [ :quiz_attempt_id, :quiz_question_id ], unique: true
  end
end
