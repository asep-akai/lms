class AddWebsiteFooterSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :landing_pages, :footer_text, :string, default: "Learning, organized.", null: false
    add_column :landing_pages, :footer_copyright, :string, default: "", null: false
    add_column :landing_pages, :footer_background_style, :string, default: "cream", null: false
    add_column :landing_pages, :footer_visible, :boolean, default: true, null: false
    add_column :landing_pages, :footer_workspace_link, :boolean, default: true, null: false
    add_column :landing_navigation_items, :placement, :string, default: "header", null: false
    add_index :landing_navigation_items, [ :landing_page_id, :placement, :position ]
  end
end
