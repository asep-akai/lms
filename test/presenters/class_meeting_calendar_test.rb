require "test_helper"

class ClassMeetingCalendarTest < ActiveSupport::TestCase
  setup do
    @teacher = create_member("teacher", "calendar-teacher@example.com", "Calendar Teacher")
    @student = create_member("student", "calendar-student@example.com", "Calendar Student")
  end

  test "builds a Monday-first month grid and groups meetings in the organization timezone" do
    meeting = create_meeting(Time.utc(2026, 9, 30, 18, 30))
    calendar = ClassMeetingCalendar.new(
      scope: organizations(:one).class_meetings,
      month: "2026-10",
      time_zone: "Asia/Jakarta",
      today: Time.utc(2026, 9, 17, 12)
    )

    assert_equal "October 2026", calendar.month_label
    assert_equal Date.new(2026, 9, 28), calendar.weeks.first.first
    assert_equal Date.new(2026, 11, 1), calendar.weeks.last.last
    assert_equal [ meeting ], calendar.meetings_on(Date.new(2026, 10, 1))
    assert_equal 1, calendar.total_count
    assert_equal "2026-09", calendar.previous_month_key
    assert_equal "2026-11", calendar.next_month_key
  end

  test "falls back to the current month for an invalid month parameter" do
    calendar = ClassMeetingCalendar.new(
      scope: organizations(:one).class_meetings,
      month: "not-a-month",
      time_zone: "UTC",
      today: Time.utc(2026, 9, 17, 12)
    )

    assert_equal "2026-09", calendar.month_key
    assert calendar.current_month?
    assert calendar.today?(Date.new(2026, 9, 17))
  end

  private
    def create_meeting(starts_at)
      meeting = organizations(:one).class_meetings.new(
        teacher_membership: @teacher,
        subject: "Mathematics",
        topic: "Calendar lesson",
        starts_at: starts_at,
        delivery_mode: "onsite"
      )
      meeting.student_memberships = [ @student ]
      meeting.save!
      meeting
    end

    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
