class CreateMaterialBlocks < ActiveRecord::Migration[8.1]
  class MigrationMaterial < ActiveRecord::Base
    self.table_name = "materials"
  end

  class MigrationMaterialBlock < ActiveRecord::Base
    self.table_name = "material_blocks"
  end

  def up
    create_table :material_blocks do |t|
      t.references :material, null: false, foreign_key: true
      t.string :block_type, null: false
      t.text :body_html
      t.integer :position, null: false
      t.timestamps
    end
    add_index :material_blocks, %i[material_id position]

    MigrationMaterial.reset_column_information
    MigrationMaterialBlock.reset_column_information
    MigrationMaterial.find_each do |material|
      position = 1
      if material.body_html.present?
        MigrationMaterialBlock.create!(material_id: material.id, block_type: "text", body_html: material.body_html, position: position)
        position += 1
      end
      ActiveStorage::Attachment.where(record_type: "Material", record_id: material.id, name: "images").order(:id).find_each do |attachment|
        block = MigrationMaterialBlock.create!(material_id: material.id, block_type: "image", position: position)
        attachment.update_columns(record_type: "MaterialBlock", record_id: block.id, name: "image")
        position += 1
      end
    end

    change_column_null :materials, :body_html, true
  end

  def down
    MigrationMaterial.reset_column_information
    MigrationMaterialBlock.reset_column_information
    MigrationMaterial.find_each do |material|
      blocks = MigrationMaterialBlock.where(material_id: material.id).order(:position)
      material.update_columns(body_html: blocks.where(block_type: "text").pluck(:body_html).compact.join)
      blocks.where(block_type: "image").find_each do |block|
        ActiveStorage::Attachment.where(record_type: "MaterialBlock", record_id: block.id, name: "image")
          .update_all(record_type: "Material", record_id: material.id, name: "images")
      end
    end

    change_column_null :materials, :body_html, false
    drop_table :material_blocks
  end
end
