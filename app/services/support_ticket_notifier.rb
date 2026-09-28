class SupportTicketNotifier
  Target = Data.define(:recipient, :destination)

  def self.created(ticket, message)
    notify(ticket, event: "created", actor: message.author, message: message, targets: organization_manager_targets(ticket))
    notify_in_app(ticket, event: "created", actor: message.author, recipients: organization_manager_memberships(ticket))
  end

  def self.replied(message)
    ticket = message.support_ticket
    targets = participant_targets(ticket)
    notify(ticket, event: "replied", actor: message.author, message: message, targets: targets)
    notify_in_app(ticket, event: "replied", actor: message.author, recipients: organization_participant_memberships(ticket))
  end

  def self.escalated(ticket, actor:)
    notify(ticket, event: "escalated", actor: actor, targets: participant_targets(ticket))
    notify_in_app(ticket, event: "escalated", actor: actor, recipients: organization_participant_memberships(ticket))
  end

  def self.status_changed(ticket, actor:)
    notify(ticket, event: "status_changed", actor: actor, targets: participant_targets(ticket))
    notify_in_app(ticket, event: "status_changed", actor: actor, recipients: organization_participant_memberships(ticket))
  end

  def self.notify(ticket, event:, actor:, targets:, message: nil)
    targets
      .uniq { |target| [ target.recipient.class.name, target.recipient.id, target.destination ] }
      .reject { |target| same_person?(target.recipient, actor) }
      .each do |target|
        SupportTicketMailer.with(
          ticket: ticket,
          recipient: target.recipient,
          destination: target.destination,
          event: event,
          actor: actor,
          message: message
        ).notification.deliver_later
      end
  end

  def self.participant_targets(ticket)
    targets = [ Target.new(ticket.reporter_membership.user, "organization") ]
    targets.concat(organization_manager_targets(ticket))
    targets.concat(console_manager_targets) if ticket.escalated?
    targets
  end

  def self.organization_manager_targets(ticket)
    ticket.organization.memberships.active.includes(:user).filter_map do |membership|
      next unless membership.user.active? && membership.permission?("support_tickets.manage")

      Target.new(membership.user, "organization")
    end
  end

  def self.organization_manager_memberships(ticket)
    ticket.organization.memberships.active.includes(:user).select do |membership|
      membership.user.active? && membership.permission?("support_tickets.manage")
    end
  end

  def self.organization_participant_memberships(ticket)
    [ ticket.reporter_membership, *organization_manager_memberships(ticket) ].uniq
  end

  def self.notify_in_app(ticket, event:, actor:, recipients:)
    actor_membership = actor if actor.is_a?(Membership)
    labels = {
      "created" => "New support ticket",
      "replied" => "New support ticket reply",
      "escalated" => "Support ticket escalated",
      "status_changed" => "Support ticket status updated"
    }
    InAppNotifier.deliver_to(
      recipients,
      kind: "support_ticket_updated",
      title: labels.fetch(event),
      body: ticket.subject,
      path: InAppNotifier.path_for(:organization_support_ticket_path, ticket.organization, ticket),
      actor: actor_membership,
      notifiable: ticket
    )
  end

  def self.console_manager_targets
    Admin.where(status: "active").filter_map do |admin|
      Target.new(admin, "console") if admin.can?("support_tickets.console")
    end
  end

  def self.same_person?(recipient, actor)
    actor_record = actor.is_a?(Membership) ? actor.user : actor
    recipient == actor_record
  end

  private_class_method :notify, :participant_targets, :organization_manager_targets,
    :organization_manager_memberships, :organization_participant_memberships, :notify_in_app,
    :console_manager_targets, :same_person?
end
