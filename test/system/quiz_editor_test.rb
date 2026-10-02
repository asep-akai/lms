require "application_system_test_case"

class QuizEditorTest < ApplicationSystemTestCase
  test "course quiz creation keeps its back destination and editor labels stay distinct" do
    course = organizations(:one).courses.create!(name: "Navigation course", description: "Author a quiz from its course.")
    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
    visit new_organization_course_quiz_path(organizations(:one), course, from: "course")
    assert_link "Back to course", href: organization_course_path(organizations(:one), course)
    fill_in "Title", with: "Navigation quiz"
    click_button "Create quiz"
    assert_text "Quiz created."
    click_link "Edit quiz"
    assert_link "Back to course", href: organization_course_path(organizations(:one), course)

    2.times do |index|
      click_button "Add question"
      within("section[data-controller='question-editor']", match: :first) do
        select "Short answer", from: "Question type"
        fill_in "Expected answer", with: "Answer #{index + 1}"
        click_button "Add question"
      end
      assert_text "Question added."
      assert_selector "button[data-closed-label='Edit question']", count: index + 1
    end
    all("button", text: "Edit question", exact_text: true).last.click
    fill_in "Expected answer", with: "Updated second answer"
    click_button "Save question"
    assert_text "Question updated."
    quiz = course.quizzes.last
    assert_equal [ "Answer 1", "Updated second answer" ], quiz.questions.order(:position).pluck(:short_answer)
    assert_link "Back to course", href: organization_course_path(organizations(:one), course)
    click_link "Back to course"
    assert_current_path organization_course_path(organizations(:one), course)
  end

  test "audio playback failure gives a download fallback in player and review" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Playback course", description: "Audio fallback coverage.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Audio playback")
    question = quiz.questions.create!(question_type: "audio", content_html: "", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current)
    answer = attempt.answers.build(quiz_question: question)
    answer.audio_response.attach(io: StringIO.new("unsupported test audio"), filename: "response.aiff", content_type: "audio/aiff", identify: false)
    answer.save!

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
    visit attempt_organization_course_quiz_path(organizations(:one), course, quiz, attempt_id: attempt.id)
    assert_text "This browser could not play the audio."
    assert_link "Download audio", href: /disposition=attachment/
    attach_file "Or upload an audio file", file_fixture("sample.mp3")
    assert_selector "a[data-audio-playback-target='download'][href^='blob:'][download='sample.mp3']"
    click_button "Back to course"
    assert_text "Quiz progress saved."
    attempt.reload.submit!

    click_button "Sign out"
    assert_field "Email"
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
    visit organization_grading_attempt_path(organizations(:one), attempt)
    assert_link "Download audio", href: /disposition=attachment/
    page.execute_script("document.querySelector('audio').dispatchEvent(new Event('error'))")
    assert_text "This browser could not play the audio."
  end

  test "student records and replaces a Safari-compatible audio response" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Speaking", description: "Recorded responses.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Oral response")
    question = quiz.questions.create!(question_type: "audio", content_html: "", position: 1)

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"
    visit attempt_organization_course_quiz_path(organizations(:one), course, quiz)

    page.execute_script(<<~JAVASCRIPT)
      (() => {
        const track = { stop() {} }
        Object.defineProperty(navigator, "mediaDevices", {
          configurable: true,
          value: { getUserMedia: async () => ({ getTracks: () => [track] }) }
        })
        class TestMediaRecorder extends EventTarget {
          static isTypeSupported(type) { return type.startsWith("audio/mp4") }
          constructor(stream, options) {
            super()
            this.stream = stream
            this.mimeType = options.mimeType
            this.state = "inactive"
          }
          start() { this.state = "recording" }
          stop() {
            this.state = "inactive"
            const data = new Blob(["recorded audio"], { type: "audio/mp4" })
            this.dispatchEvent(new MessageEvent("dataavailable", { data }))
            this.dispatchEvent(new Event("stop"))
          }
        }
        Object.defineProperty(window, "MediaRecorder", { configurable: true, value: TestMediaRecorder })
      })()
    JAVASCRIPT

    click_button "Start recording"
    assert_text "Recording…"
    assert_selector "canvas[aria-label='Live microphone waveform']:not([hidden])"
    click_button "Stop recording"
    assert_text "Recording ready"
    assert_selector "audio:not([hidden])"
    assert_button "Record again"

    click_button "Submit"
    assert_selector "dialog[open]", text: "All questions are answered. Submit quiz?"
    within("dialog[open]") { click_button "Cancel" }

    click_button "Back to course"
    assert_text "Quiz progress saved."
    answer = membership.quiz_attempts.find_by!(quiz: quiz).answers.find_by!(quiz_question: question)
    assert_predicate answer.audio_response, :attached?
    assert_equal "m4a", answer.audio_response.filename.extension
    assert_equal "audio/m4a", answer.gemini_audio_content_type
  end

  test "essay word counter initializes from a saved response and updates while typing" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Writing", description: "Structured responses.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Case analysis")
    question = quiz.questions.create!(question_type: "essay", content_html: "<p>Explain your decision.</p>", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "A saved response")

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"
    visit attempt_organization_course_quiz_path(organizations(:one), course, quiz, attempt_id: attempt.id)

    assert_text "3 words"
    fill_in "Your essay", with: "One two\nthree four"
    assert_text "4 words"
  end

  test "administrator rearranges text and image blocks on a quiz page" do
    course = organizations(:one).courses.create!(name: "Writing", description: "Structured responses.")
    quiz = course.quizzes.create!(title: "Case analysis")
    quiz_page = quiz.default_page
    text_block = quiz_page.blocks.create!(block_type: "text", body_html: "<p>Read the case carefully.</p>", position: 1)
    image_block = quiz_page.blocks.build(block_type: "image", position: 2)
    image_block.image.attach(io: StringIO.new("reference image"), filename: "case.png", content_type: "image/png", identify: false)
    image_block.save!

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit edit_organization_course_quiz_path(organizations(:one), course, quiz)

    click_button "Edit page"
    within "[data-controller~='content-block-editor']" do
      within "[data-block-type='image']" do
        click_button "Move up"
      end
      click_button "Save page"
    end

    assert_text "Page updated."
    assert_equal [ image_block.id, text_block.id ], quiz_page.reload.blocks.pluck(:id)
  end

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
    within("dialog[open]") do
      assert_text "Start a new attempt? Your current attempt will be cancelled and hidden from your evaluation history."
      click_button "Cancel"
    end
    assert_no_selector "dialog[open][aria-label='Quiz connection test']"

    click_button "Start retake"
    within("dialog[open]") do
      assert_text "Start a new attempt? Your current attempt will be cancelled and hidden from your evaluation history."
      click_button "Confirm"
    end

    using_wait_time(8) do
      within "dialog[open][aria-label='Quiz connection test']" do
        assert_text "Connection warning"
        page.execute_script("window.fetch = window.__quizOriginalFetch")
        click_button "Proceed anyway"
      end
    end

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

  test "editor switches between cloze fields and feedback-only essay scoring" do
    course = organizations(:one).courses.create!(name: "Languages", description: "Mixed question formats.")
    quiz = course.quizzes.create!(title: "Grammar review")

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit edit_organization_course_quiz_path(organizations(:one), course, quiz)

    click_button "Add question"
    within("section[data-controller='question-editor']") do
      select "Multiple answers (cloze)", from: "Question type"
      assert_field "Cloze text"
      assert_no_field "Expected answer", visible: true
      fill_in "Cloze text", with: "A sentence begins with a [[capital letter]] and ends with [[punctuation]]."
      click_button "Add question"
    end
    assert_text "Question added."
    assert_predicate quiz.questions.reload.first, :cloze?

    click_button "Add question"
    within("section[data-controller='question-editor']", match: :first) do
      select "Essay", from: "Question type"
      assert_field "Result treatment", with: "feedback_only"
    end
  end
end
