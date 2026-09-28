class ClassRescheduleRequester
  class NotAllowed < StandardError; end

  def self.call!(class_meeting:, membership:, now: Time.current)
    new(class_meeting:, membership:, now:).call!
  end

  def initialize(class_meeting:, membership:, now:)
    @class_meeting = class_meeting
    @membership = membership
    @now = now
  end

  def call!
    ClassMeeting.transaction do
      @class_meeting.lock!
      @membership.lock!
      validate_request!

      @membership.update!(reschedule_quota: @membership.reschedule_quota - 1)
      @class_meeting.update!(cancelled_at: @now, cancelled_by_membership: @membership)
    end

    @class_meeting
  end

  private
    def validate_request!
      raise NotAllowed, "This class has already been cancelled." if @class_meeting.cancelled?
      raise NotAllowed, "Only the assigned student can request a reschedule." unless assigned_student?
      raise NotAllowed, "Group classes cannot be rescheduled by an individual student." unless @class_meeting.student_memberships.size == 1
      raise NotAllowed, "You do not have any reschedule quota remaining." unless @membership.reschedule_quota.positive?
      raise NotAllowed, "Rescheduling is only available until 24 hours before the class." if @now > @class_meeting.starts_at - 24.hours
    end

    def assigned_student?
      @membership.student? && @class_meeting.student_memberships.exists?(@membership.id)
    end
end
