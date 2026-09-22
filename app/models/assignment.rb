class Assignment < ApplicationRecord
  ALLOWED_DOCUMENT_TYPES = %w[
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    text/plain
    image/jpeg
    image/png
  ].freeze
  MAX_DOCUMENT_SIZE = 20.megabytes

  belongs_to :organization
  belongs_to :teacher_membership, class_name: "Membership", inverse_of: :teaching_assignments
  has_many :recipients, class_name: "AssignmentRecipient", dependent: :destroy, inverse_of: :assignment
  has_many :student_memberships, through: :recipients, source: :student_membership
  has_many :submissions, through: :recipients
  has_one_attached :document

  validates :title, presence: true, length: { maximum: 200 }
  validates :description, presence: true, length: { maximum: 20_000 }
  validates :deadline, presence: true
  validates :recipients, length: { minimum: 1, message: "must include at least one student" }
  validate :deadline_is_future, if: :deadline_must_be_future?
  validate :teacher_belongs_to_organization
  validate :document_is_supported

  scope :soonest_first, -> { order(deadline: :asc, id: :asc) }

  def cancelled? = cancelled_at.present?
  def overdue? = !cancelled? && deadline < Time.current

  private
    def deadline_is_future
      errors.add(:deadline, "must be in the future") if deadline.present? && deadline <= Time.current
    end

    def deadline_must_be_future?
      new_record? || will_save_change_to_deadline?
    end

    def teacher_belongs_to_organization
      return if teacher_membership.blank?

      errors.add(:teacher_membership, "must belong to this organization") unless teacher_membership.organization_id == organization_id
      errors.add(:teacher_membership, "must have the Teacher role") unless teacher_membership.teacher?
    end

    def document_is_supported
      return unless document.attached?

      errors.add(:document, "must be a supported document type") unless document.blob.content_type.in?(ALLOWED_DOCUMENT_TYPES)
      errors.add(:document, "must be 20 MB or smaller") if document.blob.byte_size > MAX_DOCUMENT_SIZE
    end
end
