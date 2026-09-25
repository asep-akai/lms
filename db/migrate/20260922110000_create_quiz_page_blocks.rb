class CreateQuizPageBlocks < ActiveRecord::Migration[8.1]
  class MigrationQuizPage < ActiveRecord::Base
    self.table_name = "quiz_pages"
  end

  class MigrationQuizPageBlock < ActiveRecord::Base
    self.table_name = "quiz_page_blocks"
  end

  def up
    create_table :quiz_page_blocks do |t|
      t.references :quiz_page, null: false, foreign_key: true
      t.string :block_type, null: false
      t.text :body_html
      t.integer :position, null: false

      t.timestamps
    end
    add_index :quiz_page_blocks, %i[quiz_page_id position], unique: true

    MigrationQuizPage.reset_column_information
    MigrationQuizPageBlock.reset_column_information
    MigrationQuizPage.find_each do |page|
      position = 0
      if page.instructions_html.present?
        position += 1
        MigrationQuizPageBlock.create!(quiz_page_id: page.id, block_type: "text", body_html: page.instructions_html, position: position)
      end

      next unless table_exists?(:active_storage_attachments)

      attachments = select_all(<<~SQL.squish)
        SELECT id FROM active_storage_attachments
        WHERE record_type = 'QuizPage' AND record_id = #{connection.quote(page.id)} AND name = 'images'
        ORDER BY id
      SQL
      attachments.each do |attachment|
        position += 1
        block = MigrationQuizPageBlock.create!(quiz_page_id: page.id, block_type: "image", position: position)
        execute <<~SQL.squish
          UPDATE active_storage_attachments
          SET record_type = 'QuizPageBlock', record_id = #{connection.quote(block.id)}, name = 'image'
          WHERE id = #{connection.quote(attachment.fetch("id"))}
        SQL
      end
    end
  end

  def down
    return drop_table(:quiz_page_blocks) unless table_exists?(:active_storage_attachments)

    select_all("SELECT id, quiz_page_id FROM quiz_page_blocks WHERE block_type = 'image' ORDER BY quiz_page_id, position").each do |block|
      execute <<~SQL.squish
        UPDATE active_storage_attachments
        SET record_type = 'QuizPage', record_id = #{connection.quote(block.fetch("quiz_page_id"))}, name = 'images'
        WHERE record_type = 'QuizPageBlock' AND record_id = #{connection.quote(block.fetch("id"))} AND name = 'image'
      SQL
    end
    drop_table :quiz_page_blocks
  end
end
