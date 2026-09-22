require "application_system_test_case"

class CertificateManagementTest < ApplicationSystemTestCase
  teardown { page.current_window.resize_to(1400, 1000) }

  test "administrator generates a certificate and student opens it from evaluation" do
    student = create_member("student", "system-certificate-student@example.com", "Certificate Student")
    attempt = create_reviewed_attempt(student)

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_grading_attempt_path(organizations(:one), attempt)

    click_button "Generate certificate"
    within("dialog[open]") do
      assert_text "Generate a certificate from this published score and analysis?"
      click_button "Confirm"
    end

    assert_text "Certificate generated."
    certificate = Certificate.find_by!(source: attempt)
    assert_current_path organization_certificate_path(organizations(:one), certificate, from: "grading")
    assert_text "Certificate Student"
    assert_text "1/1"
    assert_link "Open PDF"
    assert_link "Download PDF"

    click_button "Sign out"
    fill_in "Email", with: student.user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_evaluation_attempt_path(organizations(:one), attempt)
    click_link "View certificate"

    assert_current_path organization_certificate_path(organizations(:one), certificate, from: "evaluation")
    assert_text "Cells assessment"
    assert_text "Clear understanding of cell structure."

    page.current_window.resize_to(500, 900)
    viewport_width = page.evaluate_script("window.innerWidth")
    document_width = page.evaluate_script("document.documentElement.scrollWidth")
    assert_operator document_width, :<=, viewport_width
  end

  test "administrator unpublishes a certificate and generates a replacement" do
    student = create_member("student", "system-unpublished-certificate@example.com", "Certificate Student")
    issuer = organizations(:one).memberships.find_by!(user: users(:one))
    certificate = Certificates::Generate.call(source: create_reviewed_attempt(student), issued_by: issuer)

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_certificate_path(organizations(:one), certificate, from: "grading")
    click_button "Unpublish certificate"

    within("dialog[open]") do
      assert_text "you will be able to generate a new certificate"
      click_button "Confirm"
    end

    assert_text "Certificate unpublished."
    assert_text "Unpublished certificate."
    assert_no_link "Download PDF"
    assert_predicate certificate.reload, :unpublished?

    click_link "Back to grading"
    click_button "Generate certificate"
    within("dialog[open]") { click_button "Confirm" }

    assert_text "Certificate generated."
    assert_link "Download PDF"
    assert_equal 2, Certificate.where(source: certificate.source).count
  end

  private
    def create_reviewed_attempt(membership)
      course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
      course.course_enrollments.create!(membership: membership)
      quiz = course.quizzes.create!(title: "Cells assessment")
      question = quiz.questions.create!(
        question_type: "short_answer",
        content_html: "<p>Name an organelle.</p>",
        short_answer: "Mitochondrion",
        position: 1
      )
      attempt = QuizAttempt.create!(
        quiz: quiz,
        membership: membership,
        started_at: 2.hours.ago,
        last_activity_at: 1.hour.ago,
        submitted_at: 1.hour.ago,
        reviewed_at: Time.current,
        performance_analysis: "Clear understanding of cell structure."
      )
      attempt.answers.create!(quiz_question: question, short_answer_response: "Mitochondrion")
      attempt
    end

    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
