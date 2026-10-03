require "test_helper"

class QuizAttemptPerformanceAnalyzerTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :prompt, :schema, :system_instruction, :media

    def generate_json(system_instruction:, prompt:, schema:, media: [])
      @system_instruction = system_instruction
      @prompt = JSON.parse(prompt)
      @schema = schema
      @media = media
      Ai::OpenaiClient::Response.new(
        data: {
          "performance_analysis" => "Strong overall result.",
          "strengths" => "Accurate recall.",
          "weaknesses" => "No weaknesses identified in this quiz.",
          "recommendations" => "Continue with the next topic.",
          "grades" => manual_grades,
          "transcriptions" => transcriptions,
          "reviews" => reviews
        },
        model: "openai-test",
        response_id: "response-123"
      )
    end

    attr_accessor :manual_grades, :transcriptions, :reviews

    def initialize
      @manual_grades = []
      @transcriptions = []
      @reviews = []
    end
  end

  test "sends answer-key grading without student identity and returns structured feedback" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Cells check-in")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an <strong>organelle</strong>.</p>", short_answer: "Mitochondrion", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "Mitochondrion")
    client = FakeClient.new

    analysis = QuizAttemptPerformanceAnalyzer.call(attempt, client: client)

    assert_equal "Strong overall result.", analysis.performance_analysis
    assert_equal({ "correct" => 1, "total" => 1, "percentage" => 100 }, client.prompt.fetch("score"))
    assert_equal "Name an organelle.", client.prompt.dig("questions", 0, "question")
    assert client.prompt.dig("questions", 0, "correct")
    assert_not_includes client.prompt.to_json, users(:two).email
    assert_not client.schema.key?(:additionalProperties)
    assert_match "untrusted data", client.system_instruction
  end

  test "sends essay page text and images and returns a draft score" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Writing", description: "Evidence-based writing.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Source analysis")
    page = quiz.default_page
    page.blocks.create!(block_type: "text", body_html: "<p>Compare the two claims.</p>", position: 1)
    image = page.blocks.build(block_type: "image", position: 2)
    image.image.attach(io: StringIO.new("image bytes"), filename: "source.png", content_type: "image/png", identify: false)
    image.save!
    question = quiz.questions.create!(question_type: "essay", scoring_mode: "scored", content_html: "", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "The first claim has stronger evidence.")
    client = FakeClient.new
    client.manual_grades = [ { "question_id" => question.id, "correct" => true, "rationale" => "Uses the supplied evidence." } ]
    client.reviews = [ { "question_id" => question.id, "text" => "Use one more quotation to support your comparison." } ]

    analysis = QuizAttemptPerformanceAnalyzer.call(attempt, client: client)

    context = client.prompt.fetch("questions").first
    assert_equal "page_content", context.fetch("grading_basis")
    assert_equal "Compare the two claims.", context.fetch("page_text")
    assert_equal [ "page-image-#{image.id}" ], context.fetch("page_image_labels")
    assert_equal [ "page-image-#{image.id}" ], client.media.map(&:label)
    assert_equal true, analysis.grades.first.correct
    assert_equal "Uses the supplied evidence.", analysis.grades.first.rationale
    assert_equal "Use one more quotation to support your comparison.", analysis.reviews.first.text
  end

  test "sends the recorded response and uses language quality when an audio question has no prompt" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Speaking", description: "Spoken responses.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Speaking check")
    question = quiz.questions.create!(question_type: "audio", scoring_mode: "scored", content_html: "", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    answer = attempt.answers.build(quiz_question: question)
    answer.audio_response.attach(io: StringIO.new("ID3 audio"), filename: "response.mp3", content_type: "audio/mpeg", identify: false)
    answer.save!
    client = FakeClient.new
    client.manual_grades = [ { "question_id" => question.id, "correct" => false, "rationale" => "The response is incomplete." } ]
    client.transcriptions = [ { "question_id" => question.id, "text" => "This is the spoken response." } ]

    analysis = QuizAttemptPerformanceAnalyzer.call(attempt, client: client)

    context = client.prompt.fetch("questions").first
    assert_equal "language_quality", context.fetch("grading_basis")
    assert_equal "See media label: question-#{question.id}-student-audio", context.fetch("student_answer")
    assert_equal [ "question-#{question.id}-student-audio" ], client.media.map(&:label)
    assert_equal "audio/mpeg", client.media.first.mime_type
    assert_equal "This is the spoken response.", analysis.transcriptions.first.text
    assert_includes client.schema.fetch(:required), "transcriptions"
  end

  test "transcribes feedback-only audio without assigning a grade" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Speaking", description: "Reflective speaking.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Spoken reflection")
    question = quiz.questions.create!(question_type: "audio", scoring_mode: "feedback_only", content_html: "", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    answer = attempt.answers.build(quiz_question: question)
    answer.audio_response.attach(io: StringIO.new("ID3 audio"), filename: "response.mp3", content_type: "audio/mpeg", identify: false)
    answer.save!
    client = FakeClient.new
    client.transcriptions = [ { "question_id" => question.id, "text" => "A reflective spoken response." } ]

    analysis = QuizAttemptPerformanceAnalyzer.call(attempt, client: client)

    assert_empty analysis.grades
    assert_equal "A reflective spoken response.", analysis.transcriptions.first.text
  end

  test "feedback-only responses are analyzed without requesting a correct or wrong grade" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Writing", description: "Reflective writing.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Reflection")
    question = quiz.questions.create!(question_type: "essay", scoring_mode: "feedback_only", content_html: "<p>Reflect on the topic.</p>", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "A reflective response.")
    client = FakeClient.new
    client.manual_grades = [ { "question_id" => question.id, "correct" => true, "rationale" => "AI incorrectly scored feedback-only work." } ]
    client.reviews = [ { "question_id" => question.id, "text" => "Connect the reflection to a specific example." } ]

    analysis = QuizAttemptPerformanceAnalyzer.call(attempt, client: client)

    assert_empty analysis.grades
    assert_equal "Connect the reflection to a specific example.", analysis.reviews.first.text
    assert_equal "feedback_only", client.prompt.dig("questions", 0, "result_treatment")
    assert_equal "A reflective response.", client.prompt.dig("questions", 0, "student_answer")
  end
end
