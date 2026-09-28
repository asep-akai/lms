require "test_helper"

class ClassMeetingMailerTest < ActionMailer::TestCase
  test "sends the schedule in the organization timezone" do
    teacher = create_member("teacher", "teacher@example.com", "Teacher One")
    student = create_member("student", "student-one@example.com", "Student One")
    meeting = organizations(:one).class_meetings.new(
      teacher_membership: teacher,
      subject: "Mathematics",
      topic: "Introduction to algebra",
      starts_at: Time.utc(2026, 10, 10, 8, 30),
      delivery_mode: "online",
      meeting_url: "https://meet.example.com/algebra"
    )
    meeting.student_memberships = [ student ]
    meeting.save!

    email = ClassMeetingMailer.with(class_meeting: meeting, recipient_membership: student).scheduled

    assert_equal [ "student-one@example.com" ], email.to
    assert_equal "Class scheduled: Mathematics, meeting 1", email.subject
    assert_match "Introduction to algebra", email.text_part.body.to_s
    assert_match "10 October 2026 at 15:30 WIB", email.text_part.body.to_s
    assert_match "student", email.text_part.body.to_s
    assert_match "https://meet.example.com/algebra", email.text_part.body.to_s
  end

  test "notifies the teacher when a student requests rescheduling" do
    teacher = create_member("teacher", "teacher-reschedule@example.com", "Teacher One")
    student = create_member("student", "student-reschedule@example.com", "Student One")
    meeting = organizations(:one).class_meetings.new(
      teacher_membership: teacher,
      subject: "Mathematics",
      topic: "Introduction to algebra",
      starts_at: Time.utc(2026, 10, 10, 8, 30),
      delivery_mode: "onsite"
    )
    meeting.student_memberships = [ student ]
    meeting.save!

    email = ClassMeetingMailer.with(class_meeting: meeting, student_membership: student).reschedule_requested

    assert_equal [ "teacher-reschedule@example.com" ], email.to
    assert_equal "Class reschedule requested: Mathematics, meeting 1", email.subject
    assert_match "Student One", email.text_part.body.to_s
    assert_match "10 October 2026 at 15:30 WIB", email.text_part.body.to_s
  end

  private
    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
