class ClassMeetingMailer < ApplicationMailer
  def scheduled
    @class_meeting = params[:class_meeting]
    @recipient_membership = params[:recipient_membership]
    @recipient = @recipient_membership.user
    @starts_at = @class_meeting.starts_at.in_time_zone(@class_meeting.organization.timezone)
    @recipient_role = @recipient_membership == @class_meeting.teacher_membership ? "Teacher" : "Student"

    mail(
      to: @recipient.email,
      subject: "Class scheduled: #{@class_meeting.subject}, meeting #{@class_meeting.meeting_number}"
    )
  end

  def reschedule_requested
    @class_meeting = params[:class_meeting]
    @student_membership = params[:student_membership]
    @student = @student_membership.user
    @teacher = @class_meeting.teacher_membership.user
    @starts_at = @class_meeting.starts_at.in_time_zone(@class_meeting.organization.timezone)

    mail(
      to: @teacher.email,
      subject: "Class reschedule requested: #{@class_meeting.subject}, meeting #{@class_meeting.meeting_number}"
    )
  end
end
