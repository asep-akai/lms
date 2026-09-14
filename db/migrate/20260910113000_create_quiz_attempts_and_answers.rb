class CreateQuizAttemptsAndAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :quiz_attempts do |t|
      t.references :quiz, null: false, foreign_key: true
      t.references :membership, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :last_activity_at, null: false

      t.timestamps
    end
    add_index :quiz_attempts, [ :quiz_id, :membership_id ], unique: true

    create_table :quiz_answers do |t|
      t.references :quiz_attempt, null: false, foreign_key: true
      t.references :quiz_question, null: false, foreign_key: true
      t.references :quiz_answer_option, foreign_key: true
      t.text :short_answer_response

      t.timestamps
    end
    add_index :quiz_answers, [ :quiz_attempt_id, :quiz_question_id ], unique: true
  end
end
