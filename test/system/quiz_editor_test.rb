require "application_system_test_case"

class QuizEditorTest < ApplicationSystemTestCase
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

    click_button "Save question"
    assert_text "Question updated."
    assert_equal question.id, quiz.questions.reload.first.id
  end
end
