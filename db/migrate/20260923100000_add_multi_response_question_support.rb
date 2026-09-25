class AddMultiResponseQuestionSupport < ActiveRecord::Migration[8.1]
  def change
    add_column :quiz_questions, :cloze_template, :text
    add_column :quiz_questions, :scoring_mode, :string

    create_table :quiz_answer_selections do |t|
      t.references :quiz_answer, null: false, foreign_key: true
      t.references :quiz_answer_option, null: false, foreign_key: true

      t.timestamps
    end
    add_index :quiz_answer_selections, [ :quiz_answer_id, :quiz_answer_option_id ], unique: true, name: "index_quiz_answer_selections_on_answer_and_option"

    create_table :quiz_cloze_responses do |t|
      t.references :quiz_answer, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :response_text, null: false

      t.timestamps
    end
    add_index :quiz_cloze_responses, [ :quiz_answer_id, :position ], unique: true
  end
end
