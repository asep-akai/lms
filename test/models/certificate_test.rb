require "test_helper"

class CertificateTest < ActiveSupport::TestCase
  test "requires recipient and issuer memberships from the certificate organization" do
    recipient = create_member(organizations(:one), "student", "recipient@example.com", "Recipient")
    other_issuer = create_member(organizations(:two), "admin", "issuer@example.com", "Other Issuer")
    attempt = create_reviewed_attempt(recipient)
    certificate = Certificate.new(
      organization: organizations(:one),
      recipient_membership: recipient,
      issued_by_membership: other_issuer,
      source: attempt,
      certificate_type: "exam_result",
      generated_at: Time.current,
      data: {}
    )

    assert_not certificate.valid?
    assert_includes certificate.errors[:issued_by_membership], "must belong to the certificate organization"
  end

  test "records who unpublished the certificate and prevents a second unpublish" do
    recipient = create_member(organizations(:one), "student", "unpublished-recipient@example.com", "Recipient")
    issuer = organizations(:one).memberships.find_by!(user: users(:one))
    certificate = Certificates::Generate.call(source: create_reviewed_attempt(recipient), issued_by: issuer)

    certificate.unpublish!(by: issuer)

    assert_predicate certificate, :unpublished?
    assert_equal issuer, certificate.unpublished_by_membership
    assert_raises(ArgumentError) { certificate.unpublish!(by: issuer) }
  end

  private
    def create_reviewed_attempt(membership)
      course = membership.organization.courses.create!(name: "Biology", description: "Living systems.")
      course.course_enrollments.create!(membership: membership)
      quiz = course.quizzes.create!(title: "Cells")
      QuizAttempt.create!(
        quiz: quiz,
        membership: membership,
        started_at: 2.hours.ago,
        last_activity_at: 1.hour.ago,
        submitted_at: 1.hour.ago,
        reviewed_at: Time.current
      )
    end

    def create_member(organization, role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organization.memberships.create!(user: user, status: "active")
      membership.role_ids = [ organization.roles.find_by!(key: role_key).id ]
      membership
    end
end
