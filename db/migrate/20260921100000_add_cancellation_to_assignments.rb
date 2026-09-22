class AddCancellationToAssignments < ActiveRecord::Migration[8.1]
  def change
    add_column :assignments, :cancelled_at, :datetime
    add_index :assignments, :cancelled_at
  end
end
