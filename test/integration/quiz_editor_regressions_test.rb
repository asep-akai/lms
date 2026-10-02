require "test_helper"

class QuizEditorRegressionsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @course = @organization.courses.create!(name: "Editor regression course", description: "Editor regression coverage.")
    sign_in users(:one)
  end

  test "course origin survives quiz creation validation and subsequent editing" do
    get new_organization_course_quiz_path(@organization, @course, from: "course")
    assert_response :success
    assert_select "a[href='#{organization_course_path(@organization, @course)}']", text: "Back to course"
    assert_select "a[href='#{organization_course_path(@organization, @course)}']", text: "Cancel"
    assert_select "input[name='from'][value='course']"

    post organization_course_quizzes_path(@organization, @course), params: { from: "course", quiz: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "input[name='from'][value='course']"

    post organization_course_quizzes_path(@organization, @course), params: { from: "course", quiz: { title: "Course quiz" } }
    quiz = @course.quizzes.last
    assert_redirected_to organization_course_quiz_path(@organization, @course, quiz, from: "course")
    follow_redirect!
    assert_select "a[href='#{edit_organization_course_quiz_path(@organization, @course, quiz, from: "course")}']"

    post organization_course_quiz_questions_path(@organization, @course, quiz, from: "course"), params: {
      quiz_question: { question_type: "essay", content_html: "" }
    }
    assert_redirected_to edit_organization_course_quiz_path(@organization, @course, quiz, from: "course")

    patch organization_course_quiz_path(@organization, @course, quiz), params: { from: "course", quiz: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "a[href='#{organization_course_path(@organization, @course)}']", text: "Back to course"

    get new_organization_course_quiz_path(@organization, @course)
    assert_select "a", text: "Back to quizzes"
    assert_select "input[name='from']", count: 0
  end

  test "each question and page editor has unique ids and label associations" do
    quiz = @course.quizzes.create!(title: "Many editors")
    second_page = quiz.pages.create!(title: "Second page", position: 2)
    [ quiz.default_page, second_page ].each_with_index do |page, index|
      quiz.questions.create!(quiz_page: page, question_type: "short_answer", short_answer: "Answer", position: index + 1)
    end

    get edit_organization_course_quiz_path(@organization, @course, quiz)
    assert_response :success
    ids = css_select("[id]").reject { |element| element.ancestors("template").any? }.map { |element| element["id"] }
    assert_equal [], ids.tally.select { |_id, count| count > 1 }.keys
    css_select("label[for]").reject { |label| label.ancestors("template").any? }.each do |label|
      assert_equal 1, ids.count(label["for"]), "Missing or ambiguous target for #{label.text}"
    end
    assert_select "[contenteditable][aria-labelledby]", count: 3
  end
end
