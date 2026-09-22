require "test_helper"

class CertificatesTest < ActionDispatch::IntegrationTest
  setup do
    @student = create_member("student", "certificate-student@example.com", "Certificate Student")
    @teacher = create_member("teacher", "certificate-teacher@example.com", "Certificate Teacher")
    @other_teacher = create_member("teacher", "other-certificate-teacher@example.com", "Other Teacher")
    @other_student = create_member("student", "other-certificate-student@example.com", "Other Student")
    @attempt = create_reviewed_attempt(@student)
    @issuer = organizations(:one).memberships.find_by!(user: users(:one))
  end

  test "administrator generates views and downloads a certificate" do
    sign_in users(:one)

    assert_difference "Certificate.count", 1 do
      post organization_grading_attempt_certificate_path(organizations(:one), @attempt)
    end

    certificate = Certificate.order(:id).last
    assert_redirected_to organization_certificate_path(organizations(:one), certificate, from: "grading")
    assert AuditEvent.exists?(action: "certificate.generated", auditable: certificate)

    get organization_certificate_path(organizations(:one), certificate, from: "grading")
    assert_response :success
    assert_select "h1", "Cells assessment"
    assert_select "#certificate-recipient-heading", "Certificate Student"
    assert_select "dd", "1/1"
    assert_select "dd", "100%"
    assert_select "p", "Clear understanding of cell structure."
    assert_select "a", text: "Back to grading" do |links|
      assert_includes links.map { |link| link["href"] }, organization_grading_attempt_path(organizations(:one), @attempt)
    end

    get organization_certificate_path(organizations(:one), certificate, format: :pdf, download: 1)
    assert_response :success
    assert_equal "application/octet-stream", response.media_type
    assert_match(/attachment/, response.headers.fetch("Content-Disposition"))
    assert_equal response.body.bytesize.to_s, response.headers.fetch("Content-Length")
    assert_equal "binary", response.headers.fetch("Content-Transfer-Encoding")
    assert response.body.start_with?("%PDF")

    get organization_certificate_path(organizations(:one), certificate, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/inline/, response.headers.fetch("Content-Disposition"))
    assert response.body.start_with?("%PDF")

    assert_no_difference "Certificate.count" do
      post organization_grading_attempt_certificate_path(organizations(:one), @attempt)
    end
  end

  test "certificate is removed when published results are withdrawn" do
    certificate = Certificates::Generate.call(source: @attempt, issued_by: @issuer)
    sign_in users(:one)

    assert_difference "Certificate.count", -1 do
      patch organization_unreview_grading_attempt_path(organizations(:one), @attempt)
    end

    assert_not @attempt.reload.reviewed?
    assert_not Certificate.exists?(certificate.id)
    assert_match(/certificate was removed/, flash[:notice])
  end

  test "administrator unpublishes a certificate and can publish a replacement" do
    certificate = Certificates::Generate.call(source: @attempt, issued_by: @issuer)
    sign_in users(:one)

    patch unpublish_organization_certificate_path(organizations(:one), certificate, from: "grading")

    assert_redirected_to organization_certificate_path(organizations(:one), certificate, from: "grading")
    assert_predicate certificate.reload, :unpublished?
    assert_equal @issuer, certificate.unpublished_by_membership
    assert AuditEvent.exists?(action: "certificate.unpublished", auditable: certificate)

    get organization_certificate_path(organizations(:one), certificate)
    assert_response :success
    assert_select ".alert-error", text: /Unpublished certificate/
    assert_select "a", text: "Download PDF", count: 0

    get organization_certificate_path(organizations(:one), certificate, format: :pdf, download: 1)
    assert_redirected_to root_path

    sign_in @student.user
    get organization_certificates_path(organizations(:one))
    assert_response :success
    assert_select "article[data-certificate-id='#{certificate.id}']", count: 0
    get organization_certificate_path(organizations(:one), certificate)
    assert_response :not_found

    sign_in users(:one)
    assert_difference "Certificate.count", 1 do
      post organization_grading_attempt_certificate_path(organizations(:one), @attempt)
    end
    replacement = @attempt.reload.result_certificate
    assert_not_equal certificate.id, replacement.id
    assert_not_predicate replacement, :unpublished?
  end

  test "student can view only their own certificate" do
    certificate = Certificates::Generate.call(source: @attempt, issued_by: @issuer)
    other_attempt = create_reviewed_attempt(@other_student, title: "Other assessment")
    other_certificate = Certificates::Generate.call(source: other_attempt, issued_by: @issuer)
    sign_in @student.user

    get organization_certificates_path(organizations(:one))
    assert_response :success
    assert_select "article[data-certificate-id='#{certificate.id}']"
    assert_select "article[data-certificate-id='#{other_certificate.id}']", count: 0

    get organization_certificate_path(organizations(:one), certificate)
    assert_response :success
    get organization_certificate_path(organizations(:one), other_certificate)
    assert_response :not_found
  end

  test "administrator searches certificates by exam or recipient" do
    matching_certificate = Certificates::Generate.call(source: @attempt, issued_by: @issuer)
    other_attempt = create_reviewed_attempt(@other_student, title: "Ecology assessment")
    other_certificate = Certificates::Generate.call(source: other_attempt, issued_by: @issuer)
    sign_in users(:one)

    get organization_certificates_path(organizations(:one), query: "Cells assessment")

    assert_response :success
    assert_select "input[type='search'][name='query'][value='Cells assessment']"
    assert_select "article[data-certificate-id='#{matching_certificate.id}']", count: 1
    assert_select "article[data-certificate-id='#{other_certificate.id}']", count: 0

    get organization_certificates_path(organizations(:one), query: @other_student.user.email)

    assert_response :success
    assert_select "article[data-certificate-id='#{matching_certificate.id}']", count: 0
    assert_select "article[data-certificate-id='#{other_certificate.id}']", count: 1

    get organization_certificates_path(organizations(:one), query: "missing certificate")

    assert_response :success
    assert_select ".empty-state", text: /No certificates match/
    assert_select "a", text: "Clear"
  end

  test "teacher can view certificates only for students they have taught" do
    certificate = Certificates::Generate.call(source: @attempt, issued_by: @issuer)
    meeting = organizations(:one).class_meetings.new(
      teacher_membership: @teacher,
      subject: "Biology",
      topic: "Cell structure",
      starts_at: 1.day.ago,
      delivery_mode: "onsite"
    )
    meeting.student_memberships = [ @student ]
    meeting.save!

    sign_in @teacher.user
    get organization_certificates_path(organizations(:one))
    assert_redirected_to root_path
    get organization_certificate_path(organizations(:one), certificate)
    assert_response :success

    sign_in @other_teacher.user
    get organization_certificates_path(organizations(:one))
    assert_redirected_to root_path
    get organization_certificate_path(organizations(:one), certificate)
    assert_response :not_found
  end

  test "certificate cannot be generated before results are published" do
    @attempt.update!(reviewed_at: nil)
    sign_in users(:one)

    assert_no_difference "Certificate.count" do
      post organization_grading_attempt_certificate_path(organizations(:one), @attempt)
    end

    assert_redirected_to root_path
  end

  private
    def create_reviewed_attempt(membership, title: "Cells assessment")
      course = organizations(:one).courses.create!(name: "Biology #{title}", description: "Living systems.")
      course.course_enrollments.create!(membership: membership)
      quiz = course.quizzes.create!(title: title)
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
