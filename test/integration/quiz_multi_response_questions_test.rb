require "test_helper"

class QuizMultiResponseQuestionsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @course = @organization.courses.create!(name: "Integrated science", description: "Mixed response formats.")
    @quiz = @course.quizzes.create!(title: "Matter review")
    @membership = @organization.memberships.create!(user: users(:two), status: "active")
    @membership.role_ids = [ @organization.roles.find_by!(key: "student").id ]
    @course.course_enrollments.create!(membership: @membership)
  end

  test "administrator creates multiple-selection and inline cloze questions" do
    sign_in users(:one)
    page_id = @quiz.default_page.id

    assert_difference "QuizQuestion.count", 2 do
      post organization_course_quiz_questions_path(@organization, @course, @quiz), params: {
        quiz_question: {
          quiz_page_id: page_id,
          question_type: "multiple_choice_set",
          content_html: "<p>Select the state of matter.</p>",
          answer_options_attributes: {
            "0" => { content: "Solid", correct: "1" },
            "1" => { content: "Energy", correct: "0" },
            "2" => { content: "Energy", correct: "0" }
          }
        }
      }
      assert_redirected_to edit_organization_course_quiz_path(@organization, @course, @quiz)

      post organization_course_quiz_questions_path(@organization, @course, @quiz), params: {
        quiz_question: {
          quiz_page_id: page_id,
          question_type: "cloze",
          content_html: "",
          cloze_template: "Water freezes at [[zero-secret|0]] degrees [[celsius-secret|C]]."
        }
      }
      assert_redirected_to edit_organization_course_quiz_path(@organization, @course, @quiz)
    end

    multiple_set, cloze = @quiz.questions.order(:position)
    assert_predicate multiple_set, :multiple_choice_set?
    assert_equal 1, multiple_set.answer_options.count(&:correct?)
    assert_predicate cloze, :cloze?
    assert_equal [ [ "zero-secret", "0" ], [ "celsius-secret", "C" ] ], cloze.cloze_answer_sets
  end

  test "student saves multiple selections and inline cloze answers and receives exact-set grading" do
    multiple_set = build_multiple_choice_set
    cloze = @quiz.questions.create!(
      question_type: "cloze",
      content_html: "",
      cloze_template: "Water freezes at [[zero-secret|0]] degrees [[celsius-secret|C]].",
      position: 2
    )
    sign_in users(:two)

    get attempt_organization_course_quiz_path(@organization, @course, @quiz, question: multiple_set.position)
    assert_response :success
    assert_select "input[type='checkbox'][name='quiz_answer[selected_option_ids][]']", count: 3

    correct_ids = multiple_set.answer_options.select(&:correct?).map(&:id)
    patch organization_course_quiz_attempt_answer_path(@organization, @course, @quiz, question_id: multiple_set.id), params: {
      quiz_answer: { selected_option_ids: correct_ids },
      next_question: cloze.position
    }
    assert_redirected_to attempt_organization_course_quiz_path(@organization, @course, @quiz, question: cloze.position)

    get attempt_organization_course_quiz_path(@organization, @course, @quiz, question: cloze.position)
    assert_response :success
    assert_select "input[name='quiz_answer[cloze_responses][1]']"
    assert_select "input[name='quiz_answer[cloze_responses][2]']"
    assert_includes response.body, "Water freezes at"
    assert_includes response.body, "degrees"
    assert_not_includes response.body, "zero-secret"
    assert_not_includes response.body, "celsius-secret"

    patch organization_course_quiz_attempt_answer_path(@organization, @course, @quiz, question_id: cloze.id), params: {
      quiz_answer: { cloze_responses: { "1" => "0", "2" => "C" } },
      submit_attempt: "1"
    }

    attempt = @membership.quiz_attempts.find_by!(quiz: @quiz)
    assert_predicate attempt, :submitted?
    assert_equal correct_ids.sort, attempt.answers.find_by!(quiz_question: multiple_set).selected_options.ids.sort
    assert_equal [ "0", "C" ], attempt.answers.find_by!(quiz_question: cloze).cloze_responses.order(:position).pluck(:response_text)
    grading = QuizAttemptGrader.new(attempt)
    assert_equal 2, grading.correct_count
    assert_equal 2, grading.total_count
    assert_equal 100, grading.percentage
  end

  test "an extra selection or one wrong cloze blank makes the whole question incorrect" do
    multiple_set = build_multiple_choice_set
    cloze = @quiz.questions.create!(
      question_type: "cloze",
      content_html: "",
      cloze_template: "Water freezes at [[zero-secret]] degrees [[celsius-secret]].",
      position: 2
    )
    attempt = QuizAttempt.create!(quiz: @quiz, membership: @membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)

    selected_answer = attempt.answers.build(quiz_question: multiple_set)
    selected_answer.submitted_selected_option_ids = multiple_set.answer_options.ids
    assert selected_answer.save_submission

    cloze_answer = attempt.answers.build(quiz_question: cloze)
    cloze_answer.submitted_cloze_responses = { "1" => "zero-secret", "2" => "Kelvin" }
    assert cloze_answer.save_submission

    grading = QuizAttemptGrader.new(attempt)
    assert_equal 0, grading.correct_count
    assert_equal 2, grading.total_count
    assert_equal 0, grading.percentage
  end

  private
    def build_multiple_choice_set
      question = @quiz.questions.build(
        question_type: "multiple_choice_set",
        content_html: "<p>Select both states of matter.</p>",
        position: 1
      )
      question.answer_options.build(content: "Solid", correct: true)
      question.answer_options.build(content: "Liquid", correct: true)
      question.answer_options.build(content: "Energy", correct: false)
      question.save!
      question
    end
end
