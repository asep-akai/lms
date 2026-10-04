class AddBackgroundStyleToLandingSections < ActiveRecord::Migration[8.1]
  def change
    add_column :landing_sections, :background_style, :string, default: "auto", null: false
  end
end
