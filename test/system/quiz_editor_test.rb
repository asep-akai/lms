require "application_system_test_case"

class QuizEditorTest < ApplicationSystemTestCase
  test "back to course saves the current quiz answer" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Cells quiz")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"
    visit attempt_organization_course_quiz_path(organizations(:one), course, quiz)

    find("textarea").fill_in with: "Mitochondrion"
    click_button "Back to course"

    assert_current_path organization_course_path(organizations(:one), course)
    assert_text "Quiz progress saved."
    attempt = QuizAttempt.find_by!(quiz: quiz, membership: membership)
    assert_equal "Mitochondrion", attempt.answers.find_by!(quiz_question: question).short_answer_response
  end

  test "student confirms an incomplete quiz before submitting" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Cells quiz")
    quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"
    visit attempt_organization_course_quiz_path(organizations(:one), course, quiz)

    click_button "Submit"
    assert_selector "dialog[open]", text: "1 question is unanswered. Submit anyway?"
    within "dialog[open]" do
      click_button "Confirm"
    end

    assert_text "Quiz submitted. Your attempt is in review."
    assert_current_path organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    assert_text "Attempt submitted"
    assert_selector "nav[aria-label='Course module navigation']"
    assert_predicate QuizAttempt.find_by!(quiz: quiz, membership: membership), :submitted?
  end

  test "failed connection benchmark lasts five seconds and repeats until it passes" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Connection quiz")
    quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"
    visit organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    page.execute_script("window.__quizOriginalFetch = window.fetch.bind(window); window.fetch = () => Promise.reject(new TypeError('offline'))")

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    click_link "Start quiz"

    using_wait_time(8) do
      within "dialog[open][aria-label='Quiz connection test']" do
        assert_text "Connection warning"
        assert_text "could not reach the server"
        assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at, :>=, 4.8
        assert_text "benchmark will run again next time"
        click_button "Retry benchmark"
        assert_text "Testing your connection"
      end
    end

    using_wait_time(8) do
      within "dialog[open][aria-label='Quiz connection test']" do
        assert_text "Connection warning"
        click_button "Stay here"
      end
    end

    click_link "Start quiz"
    assert_selector "dialog[open][aria-label='Quiz connection test']"
    using_wait_time(8) do
      within "dialog[open][aria-label='Quiz connection test']" do
        assert_text "Connection warning"
        page.execute_script("window.fetch = window.__quizOriginalFetch")
        click_button "Proceed anyway"
      end
    end
    assert_text "Question 1 of 1"
  end

  test "passing connection benchmark is remembered for the browser session" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Connection quiz")
    quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"
    visit organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    page.execute_script("Object.defineProperty(window.crypto, 'randomUUID', { value: undefined, configurable: true })")

    click_link "Start quiz"
    using_wait_time(8) do
      within "dialog[open][aria-label='Quiz connection test']" do
        assert_text "Connection ready"
        assert_no_text "Unavailable"
        click_button "Continue to quiz"
      end
    end

    assert_text "Question 1 of 1"
    click_button "Back to course"
    assert_text "Quiz progress saved."
    visit organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    click_link "Resume quiz"

    assert_no_selector "dialog[open][aria-label='Quiz connection test']"
    assert_text "Question 1 of 1"
  end

  test "visible timer automatically submits the current answer" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Timed Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Fast cells quiz", time_limit_minutes: 1)
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)
    attempt = QuizAttempt.create!(
      quiz: quiz,
      membership: membership,
      started_at: Time.current,
      last_activity_at: Time.current
    )

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"
    attempt.update_column(:expires_at, 4.seconds.from_now)
    visit attempt_organization_course_quiz_path(organizations(:one), course, quiz, attempt_id: attempt.id)

    assert_text "Time remaining"
    find("textarea").fill_in with: "Mitochondrion"
    using_wait_time(8) do
      assert_text "Time is up. Your saved answers were submitted automatically."
    end

    assert_predicate attempt.reload, :timed_out?
    assert_equal "Mitochondrion", attempt.answers.find_by!(quiz_question: question).short_answer_response
  end

  test "connection check can launch a retake submission" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Retake Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Retake cells quiz", retake_limit: 1)
    quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)
    first_attempt = QuizAttempt.create!(
      quiz: quiz,
      membership: membership,
      started_at: 1.hour.ago,
      last_activity_at: 30.minutes.ago,
      submitted_at: 30.minutes.ago
    )

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"
    visit organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    page.execute_script("window.__quizOriginalFetch = window.fetch.bind(window); window.fetch = () => Promise.reject(new TypeError('offline'))")

    click_button "Start retake"

    using_wait_time(8) do
      within "dialog[open][aria-label='Quiz connection test']" do
        assert_text "Connection warning"
        page.execute_script("window.fetch = window.__quizOriginalFetch")
        click_button "Proceed anyway"
      end
    end
    within("dialog[open]") { click_button "Confirm" }

    assert_text "Retake started. Your previous attempt is no longer active."
    assert_text "Question 1 of 1"
    assert_predicate first_attempt.reload, :cancelled?
    assert_equal 2, membership.quiz_attempts.active.find_by!(quiz: quiz).attempt_number
  end

  test "editor keeps questions collapsed until their edit button is used" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    quiz = course.quizzes.create!(title: "Cells quiz")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name

    visit edit_organization_course_quiz_path(organizations(:one), course, quiz)
    assert_text "Question 1"
    assert_no_selector "[contenteditable]"

    click_button "Edit question"
    assert_selector "[contenteditable]"
    find("[contenteditable]").click
    page.driver.browser.action.send_keys("More detail").perform
    click_button "Bulleted list"
    assert_selector "[contenteditable] ul", text: "More detail"
    assert_equal "disc", page.evaluate_script("getComputedStyle(document.querySelector('[contenteditable] ul')).listStyleType")

    click_button "Save question"
    assert_text "Question updated."
    assert_equal question.id, quiz.questions.reload.first.id
  end
end
