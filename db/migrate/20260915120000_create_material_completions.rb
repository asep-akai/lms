class CreateMaterialCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :material_completions do |t|
      t.references :material, null: false, foreign_key: true
      t.references :membership, null: false, foreign_key: true
      t.datetime :completed_at, null: false

      t.timestamps
    end

    add_index :material_completions, %i[material_id membership_id], unique: true
  end
end
