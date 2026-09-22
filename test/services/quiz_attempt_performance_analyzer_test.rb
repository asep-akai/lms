require "test_helper"

class QuizAttemptPerformanceAnalyzerTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :prompt, :schema, :system_instruction

    def generate_json(system_instruction:, prompt:, schema:)
      @system_instruction = system_instruction
      @prompt = JSON.parse(prompt)
      @schema = schema
      Ai::GeminiClient::Response.new(
        data: {
          "performance_analysis" => "Strong overall result.",
          "strengths" => "Accurate recall.",
          "weaknesses" => "No weaknesses identified in this quiz.",
          "recommendations" => "Continue with the next topic."
        },
        model: "gemini-test",
        response_id: "response-123"
      )
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
end
