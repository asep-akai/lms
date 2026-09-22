class ClassMeetingFeedbackPolicy < ApplicationPolicy
  def index?
    permitted?("class_meeting_feedbacks.index") || (record.respond_to?(:class_meeting) && assigned_participant?)
  end

  def show?
    return true if permitted?("class_meeting_feedbacks.index")
    return false unless assigned_participant?
    return true if class_teacher?

    record.teacher_feedback? || record.author_membership_id == Current.membership.id
  end

  def create?
    return false unless Current.membership&.active?
    return false unless record.author_membership_id == Current.membership.id
    return false unless record.class_meeting.started?

    expected_role = record.class_meeting.feedback_role_for(Current.membership)
    return false unless expected_role.present? && record.author_role == expected_role

    !record.class_meeting.feedbacks.exists?(author_membership: Current.membership)
  end

  def view_internal?
    permitted?("class_meeting_feedbacks.index") || class_teacher?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      membership = Current.membership
      return scope.none unless membership&.active?

      organization_feedbacks = scope
        .joins(:class_meeting)
        .where(class_meetings: { organization_id: Current.organization.id })
      return organization_feedbacks if principal.can?("class_meeting_feedbacks.index", organization: Current.organization)

      teacher_meetings = ClassMeeting.where(organization: Current.organization, teacher_membership: membership).select(:id)
      student_meetings = ClassMeeting
        .joins(:class_meeting_students)
        .where(organization: Current.organization, class_meeting_students: { membership_id: membership.id })
        .select(:id)

      organization_feedbacks.where(class_meeting_id: teacher_meetings)
        .or(organization_feedbacks.where(class_meeting_id: student_meetings, author_role: "teacher"))
        .or(organization_feedbacks.where(class_meeting_id: student_meetings, author_membership_id: membership.id))
    end
  end

  private
    def assigned_participant?
      Current.membership&.active? && record.class_meeting.feedback_role_for(Current.membership).present?
    end

    def class_teacher?
      record.class_meeting.teacher_membership_id == Current.membership.id
    end
end
