require "test_helper"

class QuizAttemptLimitsTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(name: "Limited Student", email: "limited-student@example.com", password: "password", status: "active")
    @student = organizations(:one).memberships.create!(user: user, status: "active")
    @student.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    @course = organizations(:one).courses.create!(name: "Advanced Biology", description: "Living systems.")
    @course.course_enrollments.create!(membership: @student)
    @quiz = @course.quizzes.create!(title: "Timed assessment", retake_limit: 1, time_limit_minutes: 30)
    @question = @quiz.questions.create!(
      question_type: "short_answer",
      content_html: "<p>Name an organelle.</p>",
      short_answer: "Mitochondrion",
      position: 1
    )
  end

  test "administrator edits optional retake and time limit settings" do
    sign_in users(:one)

    get edit_organization_course_quiz_path(organizations(:one), @course, @quiz)
    assert_response :success
    assert_select "input[name='quiz[retake_limit]'][value='1']"
    assert_select "input[name='quiz[time_limit_minutes]'][value='30']"

    patch organization_course_quiz_path(organizations(:one), @course, @quiz), params: {
      quiz: {
        title: @quiz.title,
        description: "Updated rules.",
        retake_limit: "2",
        time_limit_minutes: "45"
      }
    }

    assert_redirected_to organization_course_quiz_path(organizations(:one), @course, @quiz)
    assert_equal 2, @quiz.reload.retake_limit
    assert_equal 45, @quiz.time_limit_minutes
  end

  test "timer is based on the original start time and submits after expiry" do
    sign_in @student.user

    travel_to Time.zone.local(2026, 9, 21, 10, 0, 0) do
      get organization_course_quiz_path(organizations(:one), @course, @quiz, from: "course")
      assert_response :success
      assert_select "li", text: /timer starts.*continues if you leave or close/m
      assert_select "strong", "1 of 1 remaining"

      get attempt_organization_course_quiz_path(organizations(:one), @course, @quiz)
      assert_response :success
      attempt = QuizAttempt.find_by!(quiz: @quiz, membership: @student)
      assert_equal Time.current + 30.minutes, attempt.expires_at
      assert_select "[data-controller='quiz-timer'][data-quiz-timer-expires-at-value='#{attempt.expires_at.iso8601(3)}']"

      patch organization_course_quiz_attempt_answer_path(organizations(:one), @course, @quiz, question_id: @question.id), params: {
        quiz_attempt_id: attempt.id,
        quiz_answer: { short_answer_response: "Mitochondrion" },
        leave_quiz: "1"
      }
      assert_redirected_to organization_course_path(organizations(:one), @course)

      travel 15.minutes
      get attempt_organization_course_quiz_path(organizations(:one), @course, @quiz, attempt_id: attempt.id)
      assert_response :success
      assert_equal Time.zone.local(2026, 9, 21, 10, 30, 0), attempt.reload.expires_at

      travel 16.minutes
      get attempt_organization_course_quiz_path(organizations(:one), @course, @quiz, attempt_id: attempt.id)
      assert_redirected_to organization_course_quiz_path(organizations(:one), @course, @quiz, from: "course")
      assert_predicate attempt.reload, :timed_out?
      assert_predicate attempt, :submitted?
      assert AuditEvent.exists?(action: "quiz_attempt.timed_out", auditable: attempt)
    end
  end

  test "student retakes a submitted quiz and the prior attempt becomes staff-only history" do
    first_attempt = QuizAttemptStarter.call(quiz: @quiz, membership: @student).attempt
    first_attempt.answers.create!(quiz_question: @question, short_answer_response: "Mitochondrion")
    first_attempt.submit!
    first_attempt.update!(reviewed_at: Time.current, performance_analysis: "Good recall.")
    issuer = organizations(:one).memberships.find_by!(user: users(:one))
    certificate = Certificates::Generate.call(source: first_attempt, issued_by: issuer)
    sign_in @student.user

    post retake_organization_course_quiz_path(organizations(:one), @course, @quiz)

    replacement = @student.quiz_attempts.active.find_by!(quiz: @quiz)
    assert_redirected_to attempt_organization_course_quiz_path(organizations(:one), @course, @quiz, attempt_id: replacement.id)
    assert_predicate first_attempt.reload, :cancelled?
    assert_equal replacement, first_attempt.superseded_by_attempt
    assert_not Certificate.exists?(certificate.id)
    assert AuditEvent.exists?(action: "quiz_attempt.cancelled_for_retake", auditable: first_attempt)

    get organization_evaluation_attempt_path(organizations(:one), first_attempt)
    assert_redirected_to root_path
    get organization_evaluation_path(organizations(:one))
    assert_select "tr", { text: /Timed assessment/, count: 0 }

    replacement.submit!
    get organization_course_quiz_path(organizations(:one), @course, @quiz, from: "course")
    assert_select "strong", "0 of 1 remaining"
    post retake_organization_course_quiz_path(organizations(:one), @course, @quiz)
    assert_redirected_to organization_course_quiz_path(organizations(:one), @course, @quiz, from: "course")
    assert_equal "You have used every retake available for this quiz.", flash[:alert]
    assert_equal 2, @student.quiz_attempts.where(quiz: @quiz).count

    sign_in users(:one)
    get organization_grading_path(organizations(:one), status: "cancelled")
    assert_response :success
    assert_select "tr", text: /Timed assessment.*Limited Student.*Cancelled for retake/m
    assert_select "a[href='#{organization_grading_attempt_path(organizations(:one), first_attempt)}']", text: "View audit record"
  end
end
