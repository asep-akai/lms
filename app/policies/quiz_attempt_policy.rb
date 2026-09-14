class QuizAttemptPolicy < ApplicationPolicy
  def index? = permitted?("quiz_attempts.index")
  def show? = permitted?("quiz_attempts.show")
  def review? = permitted?("quiz_attempts.review")
  def reset? = permitted?("quiz_attempts.reset")

  def result?
    principal.is_a?(User) && Current.membership&.student? && reviewed? && record.membership_id == Current.membership.id
  end

  private
    def reviewed? = record.reviewed?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(quiz: :course).where(courses: { organization_id: Current.organization.id })
    end
  end
end
