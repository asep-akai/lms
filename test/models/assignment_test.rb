require "test_helper"

class AssignmentTest < ActiveSupport::TestCase
  setup do
    @teacher = create_member("teacher", "assignment-teacher@example.com", "Assignment Teacher")
    @student = create_member("student", "assignment-student@example.com", "Assignment Student")
    create_class_meeting(@teacher, @student)
  end

  test "assignment accepts students taught by its teacher" do
    assignment = build_assignment
    assignment.recipients.build(student_membership: @student)

    assert assignment.valid?
  end

  test "assignment rejects a student the teacher has not taught" do
    other_student = create_member("student", "other-assignment-student@example.com", "Other Student")
    assignment = build_assignment
    recipient = assignment.recipients.build(student_membership: other_student)

    assert_not assignment.valid?
    assert_includes recipient.errors[:student_membership], "must be assigned to one of the teacher's classes"
  end

  test "failed submission does not retain a submitted state" do
    assignment = build_assignment
    assignment.recipients.build(student_membership: @student)
    assignment.save!
    submission = assignment.recipients.first.build_submission

    assert_raises(ActiveRecord::RecordInvalid) { submission.submit! }
    assert_not submission.submitted?
    assert_includes submission.errors[:base], "Add a written response or at least one document before submitting"
  end

  test "submission records whether it arrived after the deadline" do
    assignment = build_assignment
    assignment.recipients.build(student_membership: @student)
    assignment.save!
    assignment.update_column(:deadline, 1.hour.ago)
    submission = assignment.recipients.first.build_submission(body: "My response")

    submission.submit!

    assert submission.late?
  end

  test "a changed deadline must remain in the future" do
    assignment = build_assignment
    assignment.recipients.build(student_membership: @student)
    assignment.save!

    assert_not assignment.update(deadline: 1.hour.ago)
    assert_includes assignment.errors[:deadline], "must be in the future"
  end

  test "a cancelled assignment is not treated as overdue" do
    assignment = build_assignment
    assignment.recipients.build(student_membership: @student)
    assignment.save!
    assignment.update_columns(deadline: 1.hour.ago, cancelled_at: Time.current)

    assert assignment.cancelled?
    assert_not assignment.overdue?
  end

  private
    def build_assignment
      organizations(:one).assignments.new(
        teacher_membership: @teacher,
        title: "Research summary",
        description: "Summarize the assigned reading.",
        deadline: 2.days.from_now
      )
    end

    def create_class_meeting(teacher, student)
      meeting = organizations(:one).class_meetings.new(
        teacher_membership: teacher,
        subject: "Research",
        topic: "Source review",
        starts_at: 1.day.ago,
        delivery_mode: "onsite"
      )
      meeting.student_memberships = [ student ]
      meeting.save!
    end

    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
