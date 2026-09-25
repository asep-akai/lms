class CreateQuizAnswerFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :quiz_answer_feedbacks do |t|
      t.references :quiz_attempt, null: false, foreign_key: true
      t.references :quiz_question, null: false, foreign_key: true
      t.text :content, null: false
      t.string :origin, null: false
      t.string :model

      t.timestamps
    end

    add_index :quiz_answer_feedbacks,
      [ :quiz_attempt_id, :quiz_question_id ],
      unique: true,
      name: "index_quiz_answer_feedbacks_on_attempt_and_question"
  end
end
