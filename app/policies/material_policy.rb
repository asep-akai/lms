class MaterialPolicy < ApplicationPolicy
  def index? = permitted?("materials.index") || Current.membership&.active?
  def show? = permitted?("materials.index") || enrolled_in_course?
  def create? = permitted?("materials.create")
  def update? = permitted?("materials.update")
  def destroy? = permitted?("materials.destroy")

  class Scope < ApplicationPolicy::Scope
    def resolve
      organization_materials = scope.joins(:course).where(courses: { organization_id: Current.organization.id })
      return organization_materials if principal.can?("materials.index", organization: Current.organization)

      organization_materials.joins(course: :course_enrollments)
        .where(course_enrollments: { membership_id: Current.membership.id })
        .distinct
    end
  end

  private
    def enrolled_in_course?
      Current.membership&.active? && record.course.course_enrollments.exists?(membership: Current.membership)
    end
end
