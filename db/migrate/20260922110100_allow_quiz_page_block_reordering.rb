class AllowQuizPageBlockReordering < ActiveRecord::Migration[8.1]
  def change
    remove_index :quiz_page_blocks, %i[quiz_page_id position]
    add_index :quiz_page_blocks, %i[quiz_page_id position]
  end
end
