require "test_helper"

class QuizEssayQuestionsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @course = @organization.courses.create!(name: "Writing", description: "Structured writing practice.")
    @quiz = @course.quizzes.create!(title: "Critical response")
    @membership = @organization.memberships.create!(user: users(:two), status: "active")
    @membership.role_ids = [ @organization.roles.find_by!(key: "student").id ]
    @course.course_enrollments.create!(membership: @membership)
  end

  test "administrator creates a page and assigns an essay question to it" do
    sign_in users(:one)

    assert_difference "QuizPage.count", 1 do
      post organization_course_quiz_pages_path(@organization, @course, @quiz), params: {
        quiz_page: {
          title: "Source text",
          blocks_attributes: {
            "0" => { block_type: "text", body_html: "<p>Read the passage and <strong>support</strong> your answer.</p>", position: 1 },
            "1" => { block_type: "image", image: fixture_file_upload("assignment.txt", "image/png"), position: 2 }
          }
        }
      }
    end
    page = @quiz.pages.find_by!(title: "Source text")
    assert_equal %w[text image], page.blocks.pluck(:block_type)

    assert_difference "QuizQuestion.count", 1 do
      post organization_course_quiz_questions_path(@organization, @course, @quiz), params: {
        quiz_question: {
          quiz_page_id: page.id,
          question_type: "essay",
          content_html: "<p>Evaluate the author's conclusion.</p>"
        }
      }
    end

    question = @quiz.questions.find_by!(question_type: "essay")
    assert_equal page, question.quiz_page
    assert_nil question.short_answer

    get edit_organization_course_quiz_path(@organization, @course, @quiz)
    assert_response :success
    assert_select "h3", text: "Source text"
    assert_select "img[alt='assignment.txt']"
    assert_select "option[selected]", text: "Source text"
    assert_select "option", text: "Essay"

    text_block = page.blocks.find_by!(block_type: "text")
    image_block = page.blocks.find_by!(block_type: "image")
    patch organization_course_quiz_page_path(@organization, @course, @quiz, page), params: {
      quiz_page: {
        title: page.title,
        blocks_attributes: {
          "1" => { id: image_block.id, block_type: "image", position: 1 },
          "0" => { id: text_block.id, block_type: "text", body_html: text_block.body_html, position: 2 }
        }
      }
    }
    assert_equal [ image_block.id, text_block.id ], page.reload.blocks.pluck(:id)
  end

  test "new pages default to the next page name without a separate ordinal label" do
    sign_in users(:one)

    get edit_organization_course_quiz_path(@organization, @course, @quiz)

    assert_response :success
    assert_select "input[name='quiz_page[title]'][value='Page 2']"
    assert_select "p.eyebrow", text: /\APage \d+\z/, count: 0

    post organization_course_quiz_pages_path(@organization, @course, @quiz), params: {
      quiz_page: { title: "" }
    }

    assert_redirected_to edit_organization_course_quiz_path(@organization, @course, @quiz)
    assert_equal "Page 2", @quiz.pages.reload.last.title
  end

  test "administrator creates an essay question without separate question text" do
    sign_in users(:one)

    assert_difference "QuizQuestion.count", 1 do
      post organization_course_quiz_questions_path(@organization, @course, @quiz), params: {
        quiz_question: {
          quiz_page_id: @quiz.default_page.id,
          question_type: "essay",
          content_html: ""
        }
      }
    end

    assert_redirected_to edit_organization_course_quiz_path(@organization, @course, @quiz)
    assert_equal "", @quiz.questions.reload.last.content_html
  end

  test "student sees shared instructions and saves a long essay from the split player" do
    page = @quiz.pages.create!(title: "Case study", position: 2)
    page.blocks.create!(block_type: "text", body_html: "<p>Use evidence from the case.</p>", position: 1)
    image_block = page.blocks.build(block_type: "image", position: 2)
    image_block.image.attach(io: StringIO.new(file_fixture("assignment.txt").binread), filename: "case-reference.png", content_type: "image/png", identify: false)
    image_block.save!
    assert image_block.image.attached?
    question = @quiz.questions.create!(quiz_page: page, question_type: "essay", content_html: "<p>What should the team do next?</p>", position: 1)

    sign_in users(:two)
    get attempt_organization_course_quiz_path(@organization, @course, @quiz)

    assert_response :success
    assert_select ".quiz-player-split"
    assert_select ".quiz-player-scroll", count: 2
    assert_select ".quiz-player-scroll:first-child" do
      assert_select "img[alt='case-reference.png']"
      assert_select "p", text: "Use evidence from the case."
      assert_select "#active-question-heading", count: 0
    end
    assert_select ".quiz-player-scroll:nth-child(2)" do
      assert_select "#active-question-heading", text: "What should the team do next?"
      assert_select "textarea[name='quiz_answer[short_answer_response]'][maxlength='50000']"
    end
    assert_select "p.eyebrow", text: "Case study", count: 0

    patch organization_course_quiz_attempt_answer_path(@organization, @course, @quiz, question_id: question.id), params: {
      quiz_answer: { short_answer_response: "The team should compare the available evidence before acting." },
      leave_quiz: "1"
    }

    attempt = @membership.quiz_attempts.find_by!(quiz: @quiz)
    assert_equal "The team should compare the available evidence before acting.", attempt.answers.find_by!(quiz_question: question).short_answer_response
  end

  test "student sees the original question layout when a page has no shared content" do
    @quiz.questions.create!(question_type: "essay", content_html: "", position: 1)

    sign_in users(:two)
    get attempt_organization_course_quiz_path(@organization, @course, @quiz)

    assert_response :success
    assert_select ".quiz-player-split", count: 0
    assert_select ".quiz-question-panel" do
      assert_select "p", text: "Question 1 · Essay"
      assert_select "#active-question-heading", count: 0
      assert_select "[data-controller='word-counter']" do
        assert_select "textarea[name='quiz_answer[short_answer_response]'][data-word-counter-target='input']"
        assert_select "[data-word-counter-target='output'][aria-live='polite']", text: "0 words"
      end
    end
  end

  test "AI creates an essay score draft that can be manually changed and restored" do
    question = @quiz.questions.create!(question_type: "essay", scoring_mode: "scored", content_html: "<p>Explain the tradeoff.</p>", position: 1)
    attempt = QuizAttempt.create!(quiz: @quiz, membership: @membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)
    attempt.answers.create!(quiz_question: question, short_answer_response: "There are costs on both sides.")

    sign_in users(:one)
    previous_api_key = ENV["OPENAI_API_KEY"]
    previous_model = ENV["OPENAI_MODEL"]
    ENV["OPENAI_API_KEY"] = "test-key"
    ENV["OPENAI_MODEL"] = "openai-test"
    request = stub_request(:post, "https://api.openai.com/v1/responses")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "response-essay",
          output: [ {
            type: "message",
            content: [ { type: "output_text", text: {
              performance_analysis: "The response addresses the tradeoff.",
              strengths: "Recognizes both sides.",
              weaknesses: "Needs more evidence.",
              recommendations: "Cite specific evidence.",
              grades: [ { question_id: question.id, correct: true, rationale: "The response answers the prompt." } ],
              transcriptions: [],
              reviews: [ { question_id: question.id, text: "Explain the costs on each side with a concrete example." } ]
            }.to_json } ]
          } ]
        }.to_json
      )
    begin
      post organization_automatic_grade_attempt_path(@organization, attempt)
    ensure
      ENV["OPENAI_API_KEY"] = previous_api_key
      ENV["OPENAI_MODEL"] = previous_model
    end
    assert_redirected_to organization_grading_attempt_path(@organization, attempt)
    assert_requested request
    assert_predicate attempt.reload, :waiting_for_confirmation?
    assert attempt.answer_ai_grades.find_by!(quiz_question: question).correct?
    assert_equal "Explain the costs on each side with a concrete example.", attempt.answer_feedbacks.find_by!(quiz_question: question).content

    get organization_grading_attempt_path(@organization, attempt)
    assert_response :success
    assert_select ".badge-active", text: "Correct"
    assert_select "p", text: "The response answers the prompt."
    assert_select "span", text: "AI-scored draft"
    assert_select "textarea[name='answer_feedback[content]']", text: "Explain the costs on each side with a concrete example."

    patch organization_answer_feedback_path(@organization, attempt, question_id: question.id), params: {
      answer_feedback: { content: "Add a concrete example and explain why it matters." }
    }
    feedback = attempt.answer_feedbacks.find_by!(quiz_question: question)
    assert_equal "reviewer", feedback.origin
    assert_equal "Add a concrete example and explain why it matters.", feedback.content

    patch organization_grade_answer_path(@organization, attempt, question_id: question.id), params: { correct: "0" }
    assert_not QuizAttemptGrader.new(attempt.reload).results.first.correct

    delete organization_reset_answer_grade_path(@organization, attempt, question_id: question.id)
    assert QuizAttemptGrader.new(attempt.reload).results.first.correct

    patch organization_review_grading_attempt_path(@organization, attempt)
    assert_predicate attempt.reload, :reviewed?

    sign_in users(:two)
    get organization_evaluation_attempt_path(@organization, attempt)
    assert_response :success
    assert_select "p", text: "Reviewer feedback"
    assert_select "p", text: "Add a concrete example and explain why it matters."
  end

  test "moving a page resequences questions by page order" do
    first_page = @quiz.default_page
    second_page = @quiz.pages.create!(title: "Second", position: 2)
    first_question = @quiz.questions.create!(quiz_page: first_page, question_type: "essay", content_html: "<p>First</p>", position: 1)
    second_question = @quiz.questions.create!(quiz_page: second_page, question_type: "essay", content_html: "<p>Second</p>", position: 2)

    sign_in users(:one)
    patch move_organization_course_quiz_page_path(@organization, @course, @quiz, second_page, direction: "up")

    assert_redirected_to edit_organization_course_quiz_path(@organization, @course, @quiz)
    assert_equal 1, second_page.reload.position
    assert_equal 2, first_page.reload.position
    assert_equal 1, second_question.reload.position
    assert_equal 2, first_question.reload.position
  end
end
