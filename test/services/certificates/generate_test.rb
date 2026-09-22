require "test_helper"

class Certificates::GenerateTest < ActiveSupport::TestCase
  setup do
    @student = create_member("student", "certificate-student@example.com", "Certificate Student")
    @attempt = create_reviewed_attempt(@student)
    @issuer = organizations(:one).memberships.find_by!(user: users(:one))
  end

  test "snapshots a published quiz result" do
    certificate = Certificates::Generate.call(source: @attempt, issued_by: @issuer)

    assert_equal "exam_result", certificate.certificate_type
    assert_equal organizations(:one), certificate.organization
    assert_equal @student, certificate.recipient_membership
    assert_equal "Cells assessment", certificate.data.fetch("exam_name")
    assert_equal "Certificate Student", certificate.data.fetch("student_name")
    assert_equal "1/1", certificate.data.fetch("score")
    assert_equal 100, certificate.data.fetch("percentage")
    assert_equal "Clear understanding of cell structure.", certificate.data.fetch("analysis")
  end

  test "returns the existing immutable certificate when generation is repeated" do
    certificate = Certificates::Generate.call(source: @attempt, issued_by: @issuer)
    @attempt.update!(performance_analysis: "Changed after generation.")

    assert_no_difference "Certificate.count" do
      repeated = Certificates::Generate.call(source: @attempt, issued_by: @issuer)
      assert_equal certificate, repeated
      assert_equal "Clear understanding of cell structure.", repeated.data.fetch("analysis")
    end
  end

  test "rejects unpublished quiz results" do
    @attempt.update!(reviewed_at: nil)

    assert_raises(ArgumentError) do
      Certificates::Generate.call(source: @attempt, issued_by: @issuer)
    end
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
        submitted_at: Time.utc(2026, 9, 18, 8),
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
