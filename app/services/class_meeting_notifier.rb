class ClassMeetingNotifier
  def self.call(class_meeting)
    class_meeting.attendee_memberships.each do |membership|
      ClassMeetingMailer.with(
        class_meeting: class_meeting,
        recipient_membership: membership
      ).scheduled.deliver_later
    end
  end
end
