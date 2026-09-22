require "test_helper"

class QuizAttemptStarterTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    user = User.create!(name: "Timed Student", email: "timed-student@example.com", password: "password", status: "active")
    @membership = organizations(:one).memberships.create!(user: user, status: "active")
    @membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    @course = organizations(:one).courses.create!(name: "Timed Biology", description: "Living systems.")
    @course.course_enrollments.create!(membership: @membership)
    @quiz = @course.quizzes.create!(title: "Timed cells quiz", retake_limit: 1, time_limit_minutes: 20)
  end

  test "starts a timed attempt and schedules its timeout" do
    result = nil

    assert_enqueued_with(job: QuizAttemptTimeoutJob) do
      result = QuizAttemptStarter.call(quiz: @quiz, membership: @membership)
    end

    attempt = result.attempt
    assert_equal 1, attempt.attempt_number
    assert_in_delta attempt.started_at + 20.minutes, attempt.expires_at, 0.001
    assert_equal 1, @quiz.remaining_retakes_for(@membership)
  end

  test "retake cancels the completed attempt and enforces the quota" do
    first_attempt = QuizAttemptStarter.call(quiz: @quiz, membership: @membership).attempt
    first_attempt.submit!

    result = QuizAttemptStarter.call(quiz: @quiz, membership: @membership, retake: true)

    assert_predicate first_attempt.reload, :cancelled?
    assert_equal "retake", first_attempt.cancelled_reason
    assert_equal result.attempt, first_attempt.superseded_by_attempt
    assert_equal 2, result.attempt.attempt_number
    assert_predicate result.attempt, :active?
    assert_equal 0, @quiz.remaining_retakes_for(@membership)

    result.attempt.submit!
    error = assert_raises(QuizAttemptStarter::RetakeUnavailable) do
      QuizAttemptStarter.call(quiz: @quiz, membership: @membership, retake: true)
    end
    assert_equal "You have used every retake available for this quiz.", error.message
  end

  test "cannot replace an in-progress attempt" do
    QuizAttemptStarter.call(quiz: @quiz, membership: @membership)

    error = assert_raises(QuizAttemptStarter::RetakeUnavailable) do
      QuizAttemptStarter.call(quiz: @quiz, membership: @membership, retake: true)
    end

    assert_equal "There is no completed attempt to retake.", error.message
  end

  test "timeout job submits an expired attempt once and records it" do
    attempt = QuizAttempt.create!(
      quiz: @quiz,
      membership: @membership,
      started_at: 30.minutes.ago,
      last_activity_at: 30.minutes.ago,
      expires_at: 10.minutes.ago
    )

    assert_difference "AuditEvent.where(action: 'quiz_attempt.timed_out').count", 1 do
      QuizAttemptTimeoutJob.perform_now(attempt.id)
    end

    assert_predicate attempt.reload, :submitted?
    assert_predicate attempt, :timed_out?
    assert_no_difference "AuditEvent.count" do
      QuizAttemptTimeoutJob.perform_now(attempt.id)
    end
  end

  test "quiz attempt settings must be valid positive integers" do
    @quiz.retake_limit = -1
    @quiz.time_limit_minutes = 0

    assert_not @quiz.valid?
    assert_includes @quiz.errors[:retake_limit], "must be greater than or equal to 0"
    assert_includes @quiz.errors[:time_limit_minutes], "must be greater than 0"
  end
end
