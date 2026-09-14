class QuizPolicy < ApplicationPolicy
  def index? = permitted?("quizzes.index") || Current.membership&.active?
  def show? = permitted?("quizzes.index") || enrolled_in_course?
  def create? = permitted?("quizzes.create")
  def update? = permitted?("quizzes.update")
  def destroy? = permitted?("quizzes.destroy")

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:course).where(courses: { organization_id: Current.organization.id })
    end
  end

  private
    def enrolled_in_course?
      return false unless Current.membership&.active? && record.respond_to?(:course)

      record.course.course_enrollments.exists?(membership: Current.membership)
    end
end
