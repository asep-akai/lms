class CoursePolicy < ApplicationPolicy
  def index? = Current.membership&.active?

  def show?
    permitted?("courses.index") || record.course_enrollments.exists?(membership: Current.membership)
  end

  def create? = permitted?("courses.create")
  def update? = permitted?("courses.update")
  def destroy? = permitted?("courses.destroy")
  def enrollments? = permitted?("course_enrollments.update")
  def update_enrollments? = enrollments?

  class Scope < ApplicationPolicy::Scope
    def resolve
      organization_courses = scope.where(organization: Current.organization)
      return organization_courses if principal.can?("courses.index", organization: Current.organization)

      organization_courses.joins(:course_enrollments)
        .where(course_enrollments: { membership_id: Current.membership.id })
        .distinct
    end
  end
end
