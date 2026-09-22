class ChangeCertificateRevocationToUnpublishing < ActiveRecord::Migration[8.1]
  INDEX_COLUMNS = %i[source_type source_id recipient_membership_id certificate_type].freeze

  def up
    rename_column :certificates, :revoked_at, :unpublished_at
    rename_column :certificates, :revoked_by_membership_id, :unpublished_by_membership_id
    remove_index :certificates, name: "index_certificates_on_source_recipient_and_type"
    add_index :certificates, INDEX_COLUMNS,
      unique: true,
      where: "unpublished_at IS NULL",
      name: "index_certificates_on_published_source_and_recipient"
  end

  def down
    remove_index :certificates, name: "index_certificates_on_published_source_and_recipient"
    add_index :certificates, INDEX_COLUMNS,
      unique: true,
      name: "index_certificates_on_source_recipient_and_type"
    rename_column :certificates, :unpublished_by_membership_id, :revoked_by_membership_id
    rename_column :certificates, :unpublished_at, :revoked_at
  end
end
