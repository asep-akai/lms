require "test_helper"

class QuizConnectionChecksTest < ActionDispatch::IntegrationTest
  setup do
    @membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    @membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    @course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    @course.course_enrollments.create!(membership: @membership)
    @quiz = @course.quizzes.create!(title: "Cells check-in")
    @quiz.questions.create!(
      question_type: "short_answer",
      content_html: "<p>Name an organelle.</p>",
      short_answer: "Mitochondrion",
      position: 1
    )
    sign_in users(:two)
  end

  test "quiz launch includes the connection test without starting an attempt" do
    get organization_course_quiz_path(organizations(:one), @course, @quiz, from: "course")

    assert_response :success
    assert_select "[data-controller='quiz-connection-check']" do
      assert_select "a[data-action='quiz-connection-check#check']", "Start quiz"
      assert_select "dialog[aria-label='Quiz connection test']" do
        assert_select "[data-quiz-connection-check-target='progressCircle']"
        assert_select "[data-quiz-connection-check-target='liveLatency']"
        assert_select "[data-quiz-connection-check-target='liveSpeed']"
        assert_select "[data-quiz-connection-check-target='progressBar']"
        assert_select "[data-quiz-connection-check-target='downloadSpeed']"
        assert_select "[data-quiz-connection-check-target='jitter']"
        assert_select "button[data-quiz-connection-check-target='retry']", "Retry benchmark"
      end
    end
    assert_not QuizAttempt.exists?(quiz: @quiz, membership: @membership)

    get organization_course_quizzes_path(organizations(:one), @course)
    assert_response :success
    assert_select "a[href='#{organization_course_quiz_path(organizations(:one), @course, @quiz)}']", text: /Cells check-in/
    assert_select "a[href='#{attempt_organization_course_quiz_path(organizations(:one), @course, @quiz)}']", count: 0

    assert_no_difference "QuizAttempt.count" do
      get connection_check_organization_course_quiz_path(organizations(:one), @course, @quiz)
    end
    assert_response :no_content
    assert_equal "no-cache", response.headers["Cache-Control"]

    assert_no_difference "QuizAttempt.count" do
      get connection_check_organization_course_quiz_path(organizations(:one), @course, @quiz, probe: "download")
    end
    assert_response :success
    assert_equal 128.kilobytes, response.body.bytesize
    assert_equal "application/octet-stream", response.media_type
  end

  test "connection test remains restricted to students who can view the quiz" do
    other_membership = organizations(:one).memberships.create!(
      user: User.create!(name: "Other Student", email: "other-connection@example.com", password: "password", status: "active"),
      status: "active"
    )
    other_membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    sign_in other_membership.user

    get connection_check_organization_course_quiz_path(organizations(:one), @course, @quiz)

    assert_redirected_to root_path
  end
end
