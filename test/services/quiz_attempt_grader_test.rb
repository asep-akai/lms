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

  test "can ignore manual overrides when a fresh automatic grade is required" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Cells")
    question = quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "Mitochondrion")
    attempt.answer_overrides.create!(quiz_question: question, correct: false)

    assert_equal 0, QuizAttemptGrader.new(attempt).correct_count
    assert_equal 1, QuizAttemptGrader.new(attempt, use_overrides: false).correct_count
  end

  test "essay questions are excluded from the score unless a reviewer scores them" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Writing", description: "Long-form responses.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Reflection")
    question = quiz.questions.create!(question_type: "essay", scoring_mode: "scored", content_html: "<p>Explain your reasoning.</p>", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "A detailed response.")

    grading = QuizAttemptGrader.new(attempt)
    assert_nil grading.results.first.correct
    assert grading.fully_graded?
    assert_not grading.scored?
    assert_equal 1, grading.optionally_unscored_count

    attempt.answer_overrides.create!(quiz_question: question, correct: true)
    grading = QuizAttemptGrader.new(attempt)
    assert grading.results.first.correct
    assert grading.fully_graded?
    assert grading.scored?
    assert_equal 1, grading.total_count
    assert_equal 100, grading.percentage
  end

  test "audio questions are excluded from the score unless a reviewer scores them" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Speaking", description: "Recorded responses.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Oral response")
    question = quiz.questions.create!(question_type: "audio", scoring_mode: "scored", content_html: "", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    answer = attempt.answers.build(quiz_question: question)
    answer.audio_response.attach(io: StringIO.new("ID3 test audio"), filename: "response.mp3", content_type: "audio/mpeg", identify: false)
    answer.save!

    grading = QuizAttemptGrader.new(attempt)
    assert_nil grading.results.first.correct
    assert grading.fully_graded?
    assert_not grading.scored?
    assert_equal 1, grading.optionally_unscored_count

    attempt.answer_overrides.create!(quiz_question: question, correct: true)
    grading = QuizAttemptGrader.new(attempt)
    assert grading.results.first.correct
    assert grading.fully_graded?
    assert grading.scored?
  end

  test "AI score is used for essay questions and a manual override can be reverted" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Writing", description: "Long-form responses.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Reflection")
    question = quiz.questions.create!(question_type: "essay", scoring_mode: "scored", content_html: "<p>Explain your reasoning.</p>", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "A detailed response.")
    attempt.answer_ai_grades.create!(quiz_question: question, correct: true, rationale: "The response fulfills the prompt.", model: "gemini-test")

    grading = QuizAttemptGrader.new(attempt)
    assert grading.results.first.correct
    assert grading.results.first.ai_grade
    assert_equal 100, grading.percentage

    attempt.answer_overrides.create!(quiz_question: question, correct: false)
    grading = QuizAttemptGrader.new(attempt.reload)
    assert_not grading.results.first.correct
    assert grading.results.first.overridden

    attempt.answer_overrides.destroy_all
    assert QuizAttemptGrader.new(attempt.reload).results.first.correct
  end

  test "feedback-only responses never contribute to the score" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Writing", description: "Long-form responses.")
    course.course_enrollments.create!(membership: membership)
    quiz = course.quizzes.create!(title: "Reflection")
    question = quiz.questions.create!(question_type: "essay", scoring_mode: "feedback_only", content_html: "<p>Reflect.</p>", position: 1)
    attempt = QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "A reflective response.")

    grading = QuizAttemptGrader.new(attempt)

    assert_nil grading.results.first.correct
    assert_not grading.scored?
    assert_equal 1, grading.optionally_unscored_count
  end
end
