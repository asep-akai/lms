require "test_helper"

class AssignmentMailerTest < ActionMailer::TestCase
  setup do
    @teacher = create_member("teacher", "assignment-mailer-teacher@example.com", "Mailer Teacher")
    @student = create_member("student", "assignment-mailer-student@example.com", "Mailer Student")
    create_class_meeting
    @assignment = organizations(:one).assignments.new(
      teacher_membership: @teacher,
      title: "Reading response",
      description: "Respond to the reading.",
      deadline: Time.utc(2026, 10, 10, 8, 30)
    )
    @recipient = @assignment.recipients.build(student_membership: @student)
    @assignment.save!
  end

  test "assigned email includes its deadline and assignment link" do
    email = AssignmentMailer.with(assignment: @assignment, recipient: @recipient).assigned

    assert_equal [ @student.user.email ], email.to
    assert_equal "New assignment: Reading response", email.subject
    assert_match "10 October 2026 at 15:30 WIB", email.text_part.body.to_s
    expected_url = Rails.application.routes.url_helpers.organization_assignment_url(
      organizations(:one),
      @assignment,
      host: "example.com"
    )
    assert_match expected_url, email.text_part.body.to_s
  end

  test "submitted email identifies a late submission" do
    @assignment.update_column(:deadline, 1.hour.ago)
    submission = @recipient.create_submission!(body: "Response", submitted_at: Time.current)
    email = AssignmentMailer.with(submission: submission).submitted

    assert_equal [ @teacher.user.email ], email.to
    assert_match "after the deadline", email.text_part.body.to_s
  end

  test "commented email sends the teacher comment to the student" do
    submission = @recipient.create_submission!(
      body: "Response",
      submitted_at: Time.current,
      teacher_comment: "Add another source.",
      commented_at: Time.current
    )
    email = AssignmentMailer.with(submission: submission).commented

    assert_equal [ @student.user.email ], email.to
    assert_match "Add another source.", email.text_part.body.to_s
  end

  test "updated email includes the revised deadline" do
    email = AssignmentMailer.with(assignment: @assignment, student: @student.user).updated

    assert_equal [ @student.user.email ], email.to
    assert_equal "Assignment updated: Reading response", email.subject
    assert_match "10 October 2026 at 15:30 WIB", email.text_part.body.to_s
  end

  test "removed email explains that the student is no longer assigned" do
    email = AssignmentMailer.with(assignment: @assignment, student: @student.user).removed

    assert_equal [ @student.user.email ], email.to
    assert_equal "Assignment removed: Reading response", email.subject
    assert_match "no longer assigned", email.text_part.body.to_s
  end

  test "cancelled email explains that submissions are closed" do
    email = AssignmentMailer.with(assignment: @assignment, student: @student.user).cancelled

    assert_equal [ @student.user.email ], email.to
    assert_equal "Assignment cancelled: Reading response", email.subject
    assert_match "can no longer submit work", email.text_part.body.to_s
  end

  private
    def create_class_meeting
      meeting = organizations(:one).class_meetings.new(
        teacher_membership: @teacher,
        subject: "Literature",
        topic: "Reading response",
        starts_at: 1.day.ago,
        delivery_mode: "onsite"
      )
      meeting.student_memberships = [ @student ]
      meeting.save!
    end

    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
