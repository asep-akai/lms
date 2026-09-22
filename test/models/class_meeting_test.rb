require "test_helper"

class ClassMeetingTest < ActiveSupport::TestCase
  setup do
    @teacher = create_member("teacher", "teacher@example.com", "Teacher One")
    @student = create_member("student", "student-one@example.com", "Student One")
  end

  test "assigns meeting numbers per normalized subject" do
    first = build_meeting(subject: "Mathematics")
    first.student_memberships = [ @student ]
    first.save!

    second = build_meeting(subject: "  mathematics  ")
    second.student_memberships = [ @student ]
    second.save!

    science = build_meeting(subject: "Science")
    science.student_memberships = [ @student ]
    science.save!

    assert_equal 1, first.meeting_number
    assert_equal 2, second.meeting_number
    assert_equal 1, science.meeting_number
  end

  test "requires an eligible teacher and at least one eligible student" do
    meeting = build_meeting
    meeting.teacher_membership = memberships(:one)

    assert_not meeting.valid?
    assert_includes meeting.errors[:teacher_membership], "must have the Teacher role"
    assert_includes meeting.errors[:student_memberships], "must include at least one student"
  end

  test "requires a safe meeting link for online classes and clears it for onsite classes" do
    online = build_meeting
    online.student_memberships = [ @student ]
    online.meeting_url = "javascript:alert(1)"

    assert_not online.valid?
    assert_includes online.errors[:meeting_url], "must be a valid HTTP or HTTPS link"

    onsite = build_meeting
    onsite.delivery_mode = "onsite"
    onsite.meeting_url = "https://meet.example.com/unused"
    onsite.student_memberships = [ @student ]
    onsite.save!

    assert_nil onsite.meeting_url
  end

  private
    def build_meeting(subject: "Mathematics")
      organizations(:one).class_meetings.new(
        teacher_membership: @teacher,
        subject: subject,
        topic: "Introduction to algebra",
        starts_at: 1.day.from_now,
        delivery_mode: "online",
        meeting_url: "https://meet.example.com/mathematics"
      )
    end

    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
