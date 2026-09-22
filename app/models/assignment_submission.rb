class AssignmentSubmission < ApplicationRecord
  belongs_to :assignment_recipient, inverse_of: :submission
  has_many_attached :documents

  delegate :assignment, :student_membership, to: :assignment_recipient

  validates :body, length: { maximum: 30_000 }, allow_blank: true
  validates :teacher_comment, length: { maximum: 20_000 }, allow_blank: true
  validate :documents_are_supported
  validate :submission_has_content, if: :submitted?

  def submitted? = submitted_at.present?
  def late? = submitted? && submitted_at > assignment.deadline

  def submit!
    raise ArgumentError, "This assignment has already been submitted." if submitted?

    self.submitted_at = Time.current
    save!
  rescue ActiveRecord::RecordInvalid
    self.submitted_at = nil
    raise
  end

  def comment!(comment)
    raise ArgumentError, "Only submitted assignments can receive comments." unless submitted?
    raise ArgumentError, "Comment can't be blank." if comment.blank?

    update!(teacher_comment: comment, commented_at: Time.current)
  end

  private
    def submission_has_content
      errors.add(:base, "Add a written response or at least one document before submitting") if body.blank? && !documents.attached?
    end

    def documents_are_supported
      documents.each do |document|
        errors.add(:documents, "must use supported document types") unless document.blob.content_type.in?(Assignment::ALLOWED_DOCUMENT_TYPES)
        errors.add(:documents, "must each be 20 MB or smaller") if document.blob.byte_size > Assignment::MAX_DOCUMENT_SIZE
      end
    end
end
