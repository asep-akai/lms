class AssignmentPolicy < ApplicationPolicy
  def index?
    Current.membership&.student? || permitted?("assignments.index")
  end

  def show?
    return false unless record.organization_id == Current.organization.id
    return true if permitted?("assignments.index") && !Current.membership&.teacher?
    return record.teacher_membership_id == Current.membership.id if Current.membership&.teacher?

    Current.membership&.student? && record.recipients.exists?(student_membership: Current.membership)
  end

  def create?
    Current.membership&.teacher? && permitted?("assignments.create")
  end

  def update?
    Current.membership&.teacher? &&
      record.teacher_membership_id == Current.membership.id &&
      !record.cancelled? &&
      permitted?("assignments.create")
  end

  alias_method :cancel?, :update?

  def review?
    return true if permitted?("assignments.review") && !Current.membership&.teacher?

    Current.membership&.teacher? && record.teacher_membership_id == Current.membership.id && permitted?("assignments.review")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      organization_assignments = scope.where(organization: Current.organization)
      if Current.membership&.teacher?
        organization_assignments.where(teacher_membership: Current.membership)
      elsif Current.membership&.student?
        organization_assignments.joins(:recipients)
          .where(assignment_recipients: { student_membership_id: Current.membership.id })
          .distinct
      elsif principal.can?("assignments.index", organization: Current.organization)
        organization_assignments
      else
        organization_assignments.none
      end
    end
  end
end
