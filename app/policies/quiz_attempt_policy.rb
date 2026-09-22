class QuizAttemptPolicy < ApplicationPolicy
  def index? = permitted?("quiz_attempts.index")
  def show? = permitted?("quiz_attempts.show")
  def review? = permitted?("quiz_attempts.review")
  def ai_analyze? = show? && permitted?("quiz_attempts.ai_analyze")
  def reset? = permitted?("quiz_attempts.reset")

  def result?
    return false unless principal.is_a?(User) && Current.membership&.active? && record.active? && reviewed?
    return true if Current.membership.student? && record.membership_id == Current.membership.id

    Current.membership.teacher? && record.membership.class_meeting_students
      .joins(:class_meeting)
      .exists?(class_meetings: {
        organization_id: Current.organization.id,
        teacher_membership_id: Current.membership.id
      })
  end

  private
    def reviewed? = record.reviewed?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(quiz: :course).where(courses: { organization_id: Current.organization.id })
    end
  end
end
