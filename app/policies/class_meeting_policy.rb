class ClassMeetingPolicy < ApplicationPolicy
  def index? = Current.membership&.active?

  def show?
    return false unless Current.membership&.active?
    return true if permitted?("class_meetings.index")

    record.teacher_membership_id == Current.membership.id || record.student_memberships.exists?(Current.membership.id)
  end

  def create? = permitted?("class_meetings.create")
  def update? = permitted?("class_meetings.update")
  def destroy? = permitted?("class_meetings.destroy")

  class Scope < ApplicationPolicy::Scope
    def resolve
      meetings = scope.where(organization: Current.organization)
      if principal.can?("class_meetings.index", organization: Current.organization)
        meetings
      else
        meetings.assigned_to(Current.membership)
      end
    end
  end
end
