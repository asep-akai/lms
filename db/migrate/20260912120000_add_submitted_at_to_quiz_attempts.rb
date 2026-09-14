class AddSubmittedAtToQuizAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :quiz_attempts, :submitted_at, :datetime
  end
end
