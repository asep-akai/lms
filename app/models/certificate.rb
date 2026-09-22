class Certificate < ApplicationRecord
  TYPES = %w[exam_result].freeze

  belongs_to :organization
  belongs_to :recipient_membership, class_name: "Membership", inverse_of: :received_certificates
  belongs_to :issued_by_membership, class_name: "Membership", optional: true, inverse_of: :issued_certificates
  belongs_to :unpublished_by_membership, class_name: "Membership", optional: true, inverse_of: :unpublished_certificates
  belongs_to :source, polymorphic: true

  validates :certificate_type, inclusion: { in: TYPES }
  validates :generated_at, presence: true
  validates :source_id, uniqueness: {
    scope: %i[source_type recipient_membership_id certificate_type],
    conditions: -> { where(unpublished_at: nil) }
  }
  validate :memberships_belong_to_organization

  scope :newest_first, -> { order(generated_at: :desc, id: :desc) }
  scope :published, -> { where(unpublished_at: nil) }

  def unpublished? = unpublished_at.present?

  def unpublish!(by:)
    raise ArgumentError, "Certificate has already been unpublished." if unpublished?

    update!(unpublished_at: Time.current, unpublished_by_membership: by)
  end

  private
    def memberships_belong_to_organization
      if recipient_membership && recipient_membership.organization_id != organization_id
        errors.add(:recipient_membership, "must belong to the certificate organization")
      end
      if issued_by_membership && issued_by_membership.organization_id != organization_id
        errors.add(:issued_by_membership, "must belong to the certificate organization")
      end
      if unpublished_by_membership && unpublished_by_membership.organization_id != organization_id
        errors.add(:unpublished_by_membership, "must belong to the certificate organization")
      end
    end
end
