class AddLastQuestionPositionToQuizAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :quiz_attempts, :last_question_position, :integer
  end
end
