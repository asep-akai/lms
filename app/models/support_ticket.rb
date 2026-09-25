class SupportTicket < ApplicationRecord
  CATEGORIES = {
    "Technical issue" => "technical_issue",
    "Account access" => "account_access",
    "Course or content" => "course_content",
    "Quiz or assignment" => "assessment",
    "Other" => "other"
  }.freeze
  PRIORITIES = %w[low normal high urgent].freeze
  STATUSES = %w[open in_progress waiting_for_reporter resolved].freeze

  belongs_to :organization
  belongs_to :reporter_membership, class_name: "Membership"
  belongs_to :escalated_by_membership, class_name: "Membership", optional: true
  has_many :messages, class_name: "SupportMessage", dependent: :destroy

  validates :subject, presence: true, length: { maximum: 180 }
  validates :category, inclusion: { in: CATEGORIES.values }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :status, inclusion: { in: STATUSES }
  validate :memberships_belong_to_organization

  scope :recent, -> { order(updated_at: :desc, id: :desc) }
  scope :escalated, -> { where.not(escalated_at: nil) }

  def escalated? = escalated_at.present?
  def resolved? = status == "resolved"

  private
    def memberships_belong_to_organization
      errors.add(:reporter_membership, "must belong to the organization") if reporter_membership&.organization_id != organization_id
      if escalated_by_membership && escalated_by_membership.organization_id != organization_id
        errors.add(:escalated_by_membership, "must belong to the organization")
      end
    end
end
