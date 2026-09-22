class AddAnalysisToQuizAttempts < ActiveRecord::Migration[8.1]
  def change
    change_table :quiz_attempts, bulk: true do |t|
      t.string :grading_mode
      t.text :performance_analysis
      t.text :strengths
      t.text :weaknesses
      t.text :recommendations
      t.datetime :ai_analysis_generated_at
      t.string :ai_model
      t.string :ai_response_id
    end

    add_index :quiz_attempts, :ai_analysis_generated_at
  end
end
