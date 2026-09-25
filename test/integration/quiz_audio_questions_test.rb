require "test_helper"

class QuizAudioQuestionsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @course = @organization.courses.create!(name: "Speaking", description: "Recorded responses.")
    @quiz = @course.quizzes.create!(title: "Oral response")
    @membership = @organization.memberships.create!(user: users(:two), status: "active")
    @membership.role_ids = [ @organization.roles.find_by!(key: "student").id ]
    @course.course_enrollments.create!(membership: @membership)
  end

  test "administrator can leave question text empty for every question type" do
    sign_in users(:one)
    page_id = @quiz.default_page.id

    assert_difference "QuizQuestion.count", 4 do
      post organization_course_quiz_questions_path(@organization, @course, @quiz), params: {
        quiz_question: {
          quiz_page_id: page_id,
          question_type: "multiple_choice",
          content_html: "",
          answer_options_attributes: {
            "0" => { content: "First", correct: "1" },
            "1" => { content: "Second", correct: "0" }
          }
        }
      }
      assert_redirected_to edit_organization_course_quiz_path(@organization, @course, @quiz)

      post organization_course_quiz_questions_path(@organization, @course, @quiz), params: {
        quiz_question: { quiz_page_id: page_id, question_type: "short_answer", content_html: "", short_answer: "Expected" }
      }
      assert_redirected_to edit_organization_course_quiz_path(@organization, @course, @quiz)

      post organization_course_quiz_questions_path(@organization, @course, @quiz), params: {
        quiz_question: { quiz_page_id: page_id, question_type: "essay", content_html: "" }
      }
      assert_redirected_to edit_organization_course_quiz_path(@organization, @course, @quiz)

      post organization_course_quiz_questions_path(@organization, @course, @quiz), params: {
        quiz_question: { quiz_page_id: page_id, question_type: "audio" }
      }
      assert_redirected_to edit_organization_course_quiz_path(@organization, @course, @quiz)
    end

    assert_equal %w[multiple_choice short_answer essay audio], @quiz.questions.order(:position).pluck(:question_type)
    assert @quiz.questions.find_by!(question_type: "essay").feedback_only?
    assert @quiz.questions.find_by!(question_type: "audio").feedback_only?
  end

  test "student uploads, resumes, and replaces a single audio response" do
    question = @quiz.questions.create!(question_type: "audio", content_html: "", position: 1)
    sign_in users(:two)

    get attempt_organization_course_quiz_path(@organization, @course, @quiz)
    assert_response :success
    assert_select "[data-controller='audio-recorder']"
    assert_select "input[type='file'][name='quiz_answer[audio_response]'][accept*='.mp3']"
    assert_select "button", text: "Start recording"

    patch organization_course_quiz_attempt_answer_path(@organization, @course, @quiz, question_id: question.id), params: {
      quiz_answer: { audio_response: fixture_file_upload("sample.mp3", "audio/mpeg") },
      leave_quiz: "1"
    }
    assert_redirected_to organization_course_path(@organization, @course)

    attempt = @membership.quiz_attempts.find_by!(quiz: @quiz)
    answer = attempt.answers.find_by!(quiz_question: question)
    assert_predicate answer.audio_response, :attached?
    assert_equal "audio/mpeg", answer.gemini_audio_content_type
    assert_equal 1, answer.audio_response.attachments.count

    get attempt_organization_course_quiz_path(@organization, @course, @quiz, attempt_id: attempt.id)
    assert_response :success
    assert_select "audio[src]"
    assert_select "button", text: "Record again"

    replacement = Rack::Test::UploadedFile.new(file_fixture("sample.mp3"), "audio/mpeg", false, original_filename: "replacement.mp3")
    patch organization_course_quiz_attempt_answer_path(@organization, @course, @quiz, question_id: question.id), params: {
      quiz_answer: { audio_response: replacement },
      leave_quiz: "1"
    }

    answer.reload
    assert_equal "replacement.mp3", answer.audio_response.filename.to_s
    assert_equal 1, answer.audio_response.attachments.count
  end

  test "student cannot save an unsupported audio upload" do
    question = @quiz.questions.create!(question_type: "audio", content_html: "", position: 1)
    sign_in users(:two)
    get attempt_organization_course_quiz_path(@organization, @course, @quiz)
    assert_response :success

    patch organization_course_quiz_attempt_answer_path(@organization, @course, @quiz, question_id: question.id), params: {
      quiz_answer: { audio_response: fixture_file_upload("assignment.txt", "text/plain") },
      leave_quiz: "1"
    }

    assert_response :unprocessable_entity
    assert_select ".field-error", text: /Gemini-compatible audio format/
    assert_not @membership.quiz_attempts.find_by!(quiz: @quiz).answers.exists?(quiz_question: question)
  end

  test "reviewer can publish an audio response without scoring it" do
    question = @quiz.questions.create!(question_type: "audio", content_html: "", position: 1)
    attempt = QuizAttempt.create!(
      quiz: @quiz,
      membership: @membership,
      started_at: Time.current,
      last_activity_at: Time.current,
      submitted_at: Time.current
    )
    answer = attempt.answers.build(quiz_question: question)
    answer.audio_response.attach(
      io: StringIO.new(file_fixture("sample.mp3").binread),
      filename: "response.mp3",
      content_type: "audio/mpeg",
      identify: false
    )
    answer.save!

    sign_in users(:one)
    get organization_grading_attempt_path(@organization, attempt)

    assert_response :success
    assert_select "audio[src]"
    assert_select "span", text: "Feedback only"
    assert_select "button", text: "Run AI analysis"

    patch organization_review_grading_attempt_path(@organization, attempt)
    assert_predicate attempt.reload, :reviewed?
    assert_empty attempt.answer_overrides

    get organization_grading_attempt_path(@organization, attempt)
    assert_response :success
    assert_select "#score-heading", text: "Not scored"
    assert_select ".badge-neutral", text: "Feedback only"
  end

  test "AI analysis stores and displays an audio transcription" do
    question = @quiz.questions.create!(question_type: "audio", scoring_mode: "feedback_only", content_html: "", position: 1)
    attempt = QuizAttempt.create!(
      quiz: @quiz,
      membership: @membership,
      started_at: Time.current,
      last_activity_at: Time.current,
      submitted_at: Time.current
    )
    answer = attempt.answers.build(quiz_question: question)
    answer.audio_response.attach(
      io: StringIO.new(file_fixture("sample.mp3").binread),
      filename: "response.mp3",
      content_type: "audio/mpeg",
      identify: false
    )
    answer.save!

    sign_in users(:one)
    previous_api_key = ENV["GEMINI_API_KEY"]
    previous_model = ENV["GEMINI_MODEL"]
    ENV["GEMINI_API_KEY"] = "test-key"
    ENV["GEMINI_MODEL"] = "gemini-test"
    request = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          responseId: "response-audio",
          candidates: [ {
            content: { parts: [ { text: {
              performance_analysis: "The spoken response is clear.",
              strengths: "Clear delivery.",
              weaknesses: "Could include more detail.",
              recommendations: "Add a supporting example.",
              grades: [],
              transcriptions: [ { question_id: question.id, text: "This is the student's spoken response." } ],
              reviews: []
            }.to_json } ] }
          } ]
        }.to_json
      )

    begin
      post organization_automatic_grade_attempt_path(@organization, attempt)
    ensure
      ENV["GEMINI_API_KEY"] = previous_api_key
      ENV["GEMINI_MODEL"] = previous_model
    end

    assert_redirected_to organization_grading_attempt_path(@organization, attempt)
    assert_requested request
    transcription = attempt.answer_ai_transcriptions.find_by!(quiz_question: question)
    assert_equal "This is the student's spoken response.", transcription.transcript
    assert_equal "gemini-test", transcription.model

    get organization_grading_attempt_path(@organization, attempt)
    assert_response :success
    assert_select "p", text: "AI transcription"
    assert_select "p", text: "This is the student's spoken response."
    assert_select "p", text: /Verify it against the recording/
  end
end
