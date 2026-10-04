class CreateLandingPages < ActiveRecord::Migration[8.1]
  def change
    create_table :landing_pages do |t|
      t.string :key, null: false, default: "home"
      t.string :site_name, null: false, default: "Kelasona"
      t.string :title, null: false
      t.text :description
      t.bigint :current_publication_id
      t.timestamps
    end
    add_index :landing_pages, :key, unique: true

    create_table :landing_sections do |t|
      t.references :landing_page, null: false, foreign_key: true
      t.string :layout, null: false, default: "story"
      t.string :eyebrow
      t.string :heading, null: false
      t.text :body
      t.text :highlights
      t.string :button_label
      t.string :button_url
      t.string :image_alt
      t.integer :position, null: false, default: 0
      t.boolean :visible, null: false, default: true
      t.timestamps
    end

    create_table :landing_publications do |t|
      t.references :landing_page, null: false, foreign_key: true
      t.jsonb :content, null: false, default: {}
      t.timestamps
    end
    add_foreign_key :landing_pages, :landing_publications, column: :current_publication_id
  end
end
