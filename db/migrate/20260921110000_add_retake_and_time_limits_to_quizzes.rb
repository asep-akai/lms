class AddRetakeAndTimeLimitsToQuizzes < ActiveRecord::Migration[8.1]
  def change
    change_table :quizzes, bulk: true do |t|
      t.integer :retake_limit
      t.integer :time_limit_minutes
    end

    remove_index :quiz_attempts, column: %i[quiz_id membership_id]

    change_table :quiz_attempts, bulk: true do |t|
      t.integer :attempt_number, default: 1, null: false
      t.datetime :expires_at
      t.datetime :timed_out_at
      t.datetime :cancelled_at
      t.string :cancelled_reason
      t.bigint :superseded_by_attempt_id
    end

    add_index :quiz_attempts, %i[quiz_id membership_id attempt_number], unique: true, name: "index_quiz_attempts_on_quiz_membership_and_number"
    add_index :quiz_attempts, %i[quiz_id membership_id], unique: true, where: "cancelled_at IS NULL", name: "index_quiz_attempts_on_active_quiz_and_membership"
    add_index :quiz_attempts, :expires_at
    add_index :quiz_attempts, :cancelled_at
    add_index :quiz_attempts, :superseded_by_attempt_id
    add_foreign_key :quiz_attempts, :quiz_attempts, column: :superseded_by_attempt_id
  end
end
