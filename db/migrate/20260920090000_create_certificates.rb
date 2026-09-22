class CreateCertificates < ActiveRecord::Migration[8.1]
  def change
    create_table :certificates do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :recipient_membership, null: false, foreign_key: { to_table: :memberships }
      t.references :issued_by_membership, null: true, foreign_key: { to_table: :memberships }
      t.references :source, polymorphic: true, null: false
      t.string :certificate_type, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :generated_at, null: false

      t.timestamps
    end

    add_index :certificates,
      %i[source_type source_id recipient_membership_id certificate_type],
      unique: true,
      name: "index_certificates_on_source_recipient_and_type"
  end
end
