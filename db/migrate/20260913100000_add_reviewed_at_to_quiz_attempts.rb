class AddReviewedAtToQuizAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :quiz_attempts, :reviewed_at, :datetime
  end
end
