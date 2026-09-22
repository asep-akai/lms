class AssignmentRecipient < ApplicationRecord
  belongs_to :assignment
  belongs_to :student_membership, class_name: "Membership", inverse_of: :assignment_recipients
  has_one :submission, class_name: "AssignmentSubmission", dependent: :destroy, inverse_of: :assignment_recipient

  validates :student_membership_id, uniqueness: { scope: :assignment_id }
  validate :student_is_eligible

  def submitted? = submission&.submitted?
  def late? = submitted? && submission.submitted_at > assignment.deadline
  def overdue? = !submitted? && assignment.overdue?

  private
    def student_is_eligible
      return if assignment.blank? || student_membership.blank?

      unless student_membership.organization_id == assignment.organization_id
        errors.add(:student_membership, "must belong to this organization")
      end
      errors.add(:student_membership, "must be active") unless student_membership.active?
      errors.add(:student_membership, "must have the Student role") unless student_membership.student?
      unless Membership.where(id: student_membership_id).taught_by(assignment.teacher_membership).exists?
        errors.add(:student_membership, "must be assigned to one of the teacher's classes")
      end
    end
end
