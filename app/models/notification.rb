class Notification < ApplicationRecord
  KINDS = %w[
    assignment_cancelled assignment_commented assignment_created assignment_submitted assignment_updated
    certificate_created class_feedback class_meeting_created class_meeting_rescheduled class_meeting_updated
    direct_message quiz_attempt_published quiz_attempt_reset support_ticket_updated
  ].freeze

  belongs_to :organization
  belongs_to :recipient_membership, class_name: "Membership"
  belongs_to :actor_membership, class_name: "Membership", optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :title, presence: true, length: { maximum: 180 }
  validates :body, length: { maximum: 500 }, allow_blank: true
  validates :path, presence: true, format: { with: %r{\A/[^/]} }
  validate :memberships_belong_to_organization

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :unread, -> { where(read_at: nil) }

  after_create_commit :broadcast_unread_count

  def read? = read_at.present?

  def mark_read!
    update_column(:read_at, Time.current) unless read?
  end

  private
    def broadcast_unread_count
      broadcast_replace_to(
        organization,
        recipient_membership,
        :notifications,
        target: ActionView::RecordIdentifier.dom_id(recipient_membership, :notification_indicator),
        partial: "organizations/notifications/indicator",
        locals: {
          membership: recipient_membership,
          unread_count: recipient_membership.notifications.unread.count
        }
      )
    end

    def memberships_belong_to_organization
      if recipient_membership&.organization_id != organization_id
        errors.add(:recipient_membership, "must belong to the organization")
      end
      if actor_membership && actor_membership.organization_id != organization_id
        errors.add(:actor_membership, "must belong to the organization")
      end
    end
end
