require "test_helper"

class SupportTicketNotifierTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @organization = organizations(:one)
    @reporter = @organization.memberships.create!(user: users(:two), status: "active")
    @reporter.role_ids = [ @organization.roles.find_by!(key: "student").id ]
    @ticket = SupportTicket.create!(
      organization: @organization,
      reporter_membership: @reporter,
      subject: "Support notification",
      category: "technical_issue",
      priority: "normal"
    )
    @message = @ticket.messages.create!(author: @reporter, body: "Please help.")
  end

  test "new ticket notifies active organization support managers but not its reporter" do
    perform_enqueued_jobs { SupportTicketNotifier.created(@ticket, @message) }

    assert_equal [ users(:one).email ], delivered_recipients
  end

  test "escalation notifies reporter and active console support administrators" do
    actor = @organization.memberships.find_by!(user: users(:one))
    @ticket.update!(escalated_at: Time.current, escalated_by_membership: actor)

    perform_enqueued_jobs { SupportTicketNotifier.escalated(@ticket, actor: actor) }

    assert_equal [ admins(:one).email, admins(:two).email, users(:two).email ].sort, delivered_recipients.sort
  end

  test "reply does not notify its author" do
    actor = @organization.memberships.find_by!(user: users(:one))
    reply = @ticket.messages.create!(author: actor, body: "We are checking this.")

    perform_enqueued_jobs { SupportTicketNotifier.replied(reply) }

    assert_equal [ users(:two).email ], delivered_recipients
  end

  private
    def delivered_recipients
      ActionMailer::Base.deliveries.flat_map(&:to)
    end
end
