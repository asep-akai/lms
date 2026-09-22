require "test_helper"

class ClassMeetingFeedbackTest < ActiveSupport::TestCase
  setup do
    @teacher = create_member("teacher", "feedback-teacher@example.com", "Feedback Teacher")
    @student = create_member("student", "feedback-student@example.com", "Feedback Student")
    @meeting = create_meeting(starts_at: 1.hour.ago)
  end

  test "one membership can submit only one feedback per class" do
    create_student_feedback
    duplicate = @meeting.feedbacks.new(
      author_membership: @student,
      author_role: "student",
      rating: 4
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:author_membership_id], "has already been taken"
  end

  test "feedback cannot be submitted before the class starts" do
    @meeting.update!(starts_at: 1.hour.from_now)
    feedback = @meeting.feedbacks.new(
      author_membership: @student,
      author_role: "student",
      rating: 4
    )

    assert_not feedback.valid?
    assert_includes feedback.errors[:class_meeting], "must have started before feedback can be submitted"
  end

  test "teacher feedback requires student-facing and planning notes" do
    feedback = @meeting.feedbacks.new(
      author_membership: @teacher,
      author_role: "teacher",
      rating: 4
    )

    assert_not feedback.valid?
    assert_includes feedback.errors[:internal_feedback], "can't be blank"
    assert_includes feedback.errors[:feedback_to_student], "can't be blank"
    assert_includes feedback.errors[:topics_discussed], "can't be blank"
    assert_includes feedback.errors[:next_topics], "can't be blank"
  end

  test "author role must match the class assignment" do
    feedback = @meeting.feedbacks.new(
      author_membership: @student,
      author_role: "teacher",
      rating: 4,
      internal_feedback: "Internal note",
      feedback_to_student: "Student feedback",
      topics_discussed: "Fractions",
      next_topics: "Decimals"
    )

    assert_not feedback.valid?
    assert_includes feedback.errors[:author_role], "does not match the class assignment"
  end

  private
    def create_student_feedback
      @meeting.feedbacks.create!(
        author_membership: @student,
        author_role: "student",
        rating: 5,
        comment: "Clear explanations."
      )
    end

    def create_meeting(starts_at:)
      meeting = organizations(:one).class_meetings.new(
        teacher_membership: @teacher,
        subject: "Mathematics",
        topic: "Fractions",
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
