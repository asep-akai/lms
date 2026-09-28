class ClassMeetingNotifier
  def self.call(class_meeting)
    class_meeting.attendee_memberships.each do |membership|
      ClassMeetingMailer.with(
        class_meeting: class_meeting,
        recipient_membership: membership
      ).scheduled.deliver_later
      InAppNotifier.deliver(
        recipient: membership,
        kind: "class_meeting_created",
        title: "New class scheduled",
        body: "#{class_meeting.subject}: #{class_meeting.topic}",
        path: class_path(class_meeting),
        notifiable: class_meeting
      )
    end
  end

  def self.updated(class_meeting, recipients:)
    InAppNotifier.deliver_to(
      recipients,
      kind: "class_meeting_updated",
      title: "Class details updated",
      body: "#{class_meeting.subject}: #{class_meeting.topic}",
      path: class_path(class_meeting),
      notifiable: class_meeting
    )
  end

  def self.rescheduled(class_meeting, student:)
    InAppNotifier.deliver(
      recipient: class_meeting.teacher_membership,
      kind: "class_meeting_rescheduled",
      title: "Class reschedule requested",
      body: "#{student.user.name} requested a reschedule for #{class_meeting.subject}.",
      path: class_path(class_meeting),
      actor: student,
      notifiable: class_meeting
    )
  end

  def self.class_path(class_meeting)
    InAppNotifier.path_for(:organization_class_meeting_path, class_meeting.organization, class_meeting)
  end

  private_class_method :class_path
end
