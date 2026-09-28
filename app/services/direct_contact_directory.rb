class DirectContactDirectory
  def initialize(membership)
    @membership = membership
  end

  def contacts
    membership.organization.memberships
      .active
      .includes(:user)
      .where(id: contact_ids)
      .order("users.name", "users.email")
      .references(:user)
  end

  def connected?(other_membership)
    other_membership&.organization_id == membership.organization_id &&
      other_membership.active? &&
      contact_ids.include?(other_membership.id)
  end

  def contact_ids
    @contact_ids ||= begin
      ids = []
      ids.concat(student_ids_for_teacher) if membership.teacher?
      ids.concat(teacher_and_peer_ids_for_student) if membership.student?
      ids.uniq - [ membership.id ]
    end
  end

  private
    attr_reader :membership

    def attended_meeting_ids
      ClassMeetingStudent.where(membership: membership).select(:class_meeting_id)
    end

    def student_ids_for_teacher
      ClassMeetingStudent
        .joins(:class_meeting)
        .where(class_meetings: { organization_id: membership.organization_id, teacher_membership_id: membership.id })
        .pluck(:membership_id)
    end

    def teacher_and_peer_ids_for_student
      teacher_ids = membership.organization.class_meetings
        .where(id: attended_meeting_ids)
        .pluck(:teacher_membership_id)
      peer_ids = ClassMeetingStudent
        .where(class_meeting_id: attended_meeting_ids)
        .where.not(membership_id: membership.id)
        .pluck(:membership_id)

      teacher_ids + peer_ids
    end
end
