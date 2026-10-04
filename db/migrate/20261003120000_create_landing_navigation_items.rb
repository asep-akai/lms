class CreateLandingNavigationItems < ActiveRecord::Migration[8.1]
  def up
    create_table :landing_navigation_items do |t|
      t.references :landing_page, null: false, foreign_key: true
      t.references :landing_section, foreign_key: true
      t.string :label, null: false
      t.string :url
      t.boolean :visible, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    execute <<~SQL
      INSERT INTO landing_navigation_items (landing_page_id, landing_section_id, label, position, created_at, updated_at)
      SELECT DISTINCT ON (landing_page_id) landing_page_id, id, 'The platform', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM landing_sections WHERE layout = 'features' AND visible = TRUE
      ORDER BY landing_page_id, position, id
    SQL
  end

  def down
    drop_table :landing_navigation_items
  end
end
