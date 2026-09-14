require "test_helper"

class QuizAttemptGraderTest < ActiveSupport::TestCase
  test "grades answer-key matches and unanswered questions" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Cells")
    answered = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)
    quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name a cell.</p>", short_answer: "Neuron", position: 2)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: answered, short_answer_response: "  mitochondrion ")

    grading = QuizAttemptGrader.new(attempt)

    assert_equal 1, grading.correct_count
    assert_equal 2, grading.total_count
    assert_equal 50, grading.percentage
    assert grading.results.first.correct
    assert_not grading.results.second.correct
  end
end
