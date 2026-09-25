require "test_helper"

class SupportTicketsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @reporter = @organization.memberships.create!(user: users(:two), status: "active")
    @reporter.role_ids = [ @organization.roles.find_by!(key: "student").id ]
  end

  test "member reports an issue and only sees their own tickets" do
    another_user = User.create!(name: "Another student", email: "another-support@example.com", password: "password")
    another_member = @organization.memberships.create!(user: another_user, status: "active")
    another_member.role_ids = [ @organization.roles.find_by!(key: "student").id ]
    other_ticket = create_ticket(reporter: another_member, subject: "Private issue")

    sign_in users(:two)
    assert_enqueued_emails 1 do
      assert_difference [ "SupportTicket.count", "SupportMessage.count" ], 1 do
        post organization_support_tickets_path(@organization), params: {
          support_ticket: { subject: "Quiz would not load", category: "assessment", priority: "high", message: "The page remained blank." }
        }
      end
    end

    ticket = SupportTicket.find_by!(subject: "Quiz would not load")
    assert_redirected_to organization_support_ticket_path(@organization, ticket)
    assert_equal @reporter, ticket.reporter_membership
    assert_equal "The page remained blank.", ticket.messages.first.body

    get organization_support_tickets_path(@organization)
    assert_response :success
    assert_select "a.btn-primary", "Report an issue"
    assert_select "table.data-table"
    assert_select "tr", text: /Quiz would not load/
    assert_select "tr", { text: /Private issue/, count: 0 }

    get organization_support_ticket_path(@organization, other_ticket)
    assert_response :not_found
  end

  test "organization administrator replies and escalates a ticket to console" do
    ticket = create_ticket(reporter: @reporter)
    sign_in users(:one)

    assert_enqueued_emails 1 do
      post reply_organization_support_ticket_path(@organization, ticket), params: { support_message: { body: "We are investigating." } }
    end
    assert_redirected_to organization_support_ticket_path(@organization, ticket)
    assert_equal users(:one), ticket.messages.reload.last.author.user

    get organization_support_ticket_path(@organization, ticket)
    assert_response :success
    assert_select ".support-thread", text: /We are investigating/
    assert_select ".support-sidebar", text: /Manage ticket/

    assert_enqueued_emails 3 do
      patch escalate_organization_support_ticket_path(@organization, ticket)
    end
    assert_redirected_to organization_support_ticket_path(@organization, ticket)
    assert_predicate ticket.reload, :escalated?
    assert_equal "in_progress", ticket.status

    sign_out users(:one)
    sign_in admins(:one), scope: :admin
    get console_support_tickets_path
    assert_response :success
    assert_select "table.data-table"
    assert_select "tr", text: /Cannot open course/

    get console_support_ticket_path(ticket)
    assert_response :success
    assert_select ".support-thread", text: /Please help/
    assert_select ".support-sidebar", text: /#{Regexp.escape(@organization.name)}/

    assert_enqueued_emails 3 do
      post reply_console_support_ticket_path(ticket), params: { support_message: { body: "Console response" } }
    end
    assert_redirected_to console_support_ticket_path(ticket)
    assert_equal admins(:one), ticket.messages.reload.last.author
  end

  test "console cannot access a ticket before escalation" do
    ticket = create_ticket(reporter: @reporter)
    sign_in admins(:one), scope: :admin

    get console_support_ticket_path(ticket)
    assert_response :not_found
  end

  test "reply rejects an unsupported attachment" do
    ticket = create_ticket(reporter: @reporter)
    sign_in users(:two)

    assert_no_difference "SupportMessage.count" do
      post reply_organization_support_ticket_path(@organization, ticket), params: {
        support_message: {
          body: "Audio log attached.",
          attachments: [ fixture_file_upload(file_fixture("sample.mp3"), "audio/mpeg") ]
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".field-error", text: /must be a PDF, office document, text file, or supported image/
  end

  test "ticket attachments require access to the ticket" do
    ticket = create_ticket(reporter: @reporter)
    message = ticket.messages.first
    message.attachments.attach(io: StringIO.new("private diagnostics"), filename: "details.txt", content_type: "text/plain")
    attachment = message.attachments.first

    sign_in users(:two)
    get attachment_organization_support_ticket_path(@organization, ticket, attachment_id: attachment.id)
    assert_response :success
    assert_equal "private diagnostics", response.body
    assert_equal "private, no-store", response.headers["Cache-Control"]

    sign_out users(:two)
    sign_in admins(:one), scope: :admin
    get attachment_console_support_ticket_path(ticket, attachment_id: attachment.id)
    assert_response :not_found

    ticket.update!(
      escalated_at: Time.current,
      escalated_by_membership: @organization.memberships.find_by!(user: users(:one))
    )
    sign_in admins(:one), scope: :admin
    get attachment_console_support_ticket_path(ticket, attachment_id: attachment.id)
    assert_response :success
    assert_equal "private diagnostics", response.body
  end

  private
    def create_ticket(reporter:, subject: "Cannot open course")
      SupportTicket.create!(
        organization: @organization, reporter_membership: reporter,
        subject: subject, category: "course_content", priority: "normal"
      ).tap { |ticket| ticket.messages.create!(author: reporter, body: "Please help.") }
    end
end
