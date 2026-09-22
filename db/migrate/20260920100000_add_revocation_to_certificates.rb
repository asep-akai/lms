class AddRevocationToCertificates < ActiveRecord::Migration[8.1]
  def change
    add_reference :certificates, :revoked_by_membership, foreign_key: { to_table: :memberships, on_delete: :nullify }
    add_column :certificates, :revoked_at, :datetime
    add_index :certificates, :revoked_at
  end
end
