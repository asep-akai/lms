class StudentPolicy < ApplicationPolicy
  def index? = permitted?("students.index") || Current.membership&.teacher?

  def show?
    return false unless record.organization == Current.organization && record.student?
    return true if permitted?("students.show")

    Current.membership&.teacher? && record.class_meeting_students
      .joins(:class_meeting)
      .exists?(class_meetings: {
        organization_id: Current.organization.id,
        teacher_membership_id: Current.membership.id
      })
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      organization_students = scope
        .joins(user: { role_assignments: :role })
        .where(
          organization_id: Current.organization.id,
          roles: { organization_id: Current.organization.id, key: "student" }
        )
        .distinct

      return organization_students if principal.can?("students.index", organization: Current.organization)
      return organization_students.taught_by(Current.membership) if Current.membership&.teacher?

      organization_students.none
    end
  end
end
