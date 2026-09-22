class CertificatePolicy < ApplicationPolicy
  def index?
    permitted?("certificates.index") || Current.membership&.student?
  end

  def show?
    return false if record.source.is_a?(QuizAttempt) && record.source.cancelled?
    return true if permitted?("certificates.index") || permitted?("certificates.create")
    return false unless Current.membership&.active?
    return true if record.recipient_membership_id == Current.membership.id

    teacher_can_view_recipient?
  end

  def create?
    permitted?("certificates.create", organization: Current.organization) &&
      record.source.is_a?(QuizAttempt) &&
      record.source.reviewed? &&
      record.source.quiz.course.organization_id == Current.organization.id
  end

  def unpublish?
    !record.unpublished? && permitted?("certificates.create", organization: record.organization)
  end

  def download? = show? && !record.unpublished?

  class Scope < ApplicationPolicy::Scope
    def resolve
      membership = Current.membership
      return scope.none unless membership&.active?

      organization_certificates = scope.where(organization: Current.organization)
      return organization_certificates if principal.can?("certificates.index", organization: Current.organization) ||
        principal.can?("certificates.create", organization: Current.organization)

      published_certificates = organization_certificates.published
      visible = published_certificates.none
      visible = visible.or(published_certificates.where(recipient_membership: membership)) if membership.student?
      if membership.teacher?
        visible = visible.or(published_certificates.where(recipient_membership_id: taught_student_ids(membership)))
      end
      visible
    end

    private
      def taught_student_ids(membership)
        ClassMeetingStudent
          .joins(:class_meeting)
          .where(class_meetings: { organization_id: Current.organization.id, teacher_membership_id: membership.id })
          .select(:membership_id)
      end
  end

  private
    def teacher_can_view_recipient?
      return false unless Current.membership.teacher?

      ClassMeetingStudent
        .joins(:class_meeting)
        .where(class_meetings: { organization_id: Current.organization.id, teacher_membership_id: Current.membership.id })
        .exists?(membership_id: record.recipient_membership_id)
    end
end
