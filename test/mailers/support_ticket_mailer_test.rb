require "test_helper"

class SupportTicketMailerTest < ActionMailer::TestCase
  setup do
    @organization = organizations(:one)
    @reporter = @organization.memberships.create!(user: users(:two), status: "active")
    @reporter.role_ids = [ @organization.roles.find_by!(key: "student").id ]
    @ticket = SupportTicket.create!(
      organization: @organization,
      reporter_membership: @reporter,
      subject: "Quiz player is unavailable",
      category: "assessment",
      priority: "high"
    )
    @message = @ticket.messages.create!(author: @reporter, body: "The page is blank after I start the quiz.")
  end

  test "organization notification links to the organization ticket" do
    recipient = users(:one)
    email = SupportTicketMailer.with(
      ticket: @ticket,
      recipient: recipient,
      destination: "organization",
      event: "created",
      actor: @reporter,
      message: @message
    ).notification

    assert_equal [ recipient.email ], email.to
    assert_equal "New support ticket: Quiz player is unavailable", email.subject
    assert_match "The page is blank", email.text_part.body.to_s
    expected_url = Rails.application.routes.url_helpers.organization_support_ticket_url(
      @organization, @ticket, host: "example.com"
    )
    assert_match expected_url, email.text_part.body.to_s
  end

  test "console notification links to the console ticket" do
    recipient = admins(:one)
    email = SupportTicketMailer.with(
      ticket: @ticket,
      recipient: recipient,
      destination: "console",
      event: "escalated",
      actor: @organization.memberships.find_by!(user: users(:one))
    ).notification

    assert_equal [ recipient.email ], email.to
    assert_equal "Support ticket escalated: Quiz player is unavailable", email.subject
    expected_url = Rails.application.routes.url_helpers.console_support_ticket_url(@ticket, host: "example.com")
    assert_match expected_url, email.text_part.body.to_s
  end
end
