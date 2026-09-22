class AddVideoUrlToMaterialBlocks < ActiveRecord::Migration[8.1]
  def change
    add_column :material_blocks, :video_url, :string
  end
end
