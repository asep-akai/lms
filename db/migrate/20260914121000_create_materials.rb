class CreateMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :materials do |t|
      t.references :course, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body_html, null: false

      t.timestamps
    end
  end
end
