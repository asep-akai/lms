class InAppNotifier
  class << self
    def deliver(recipient:, kind:, title:, path:, body: nil, actor: Current.membership, notifiable: nil)
      return if recipient.blank? || recipient == actor || !recipient.active? || !recipient.notification_recipient?

      recipient.notifications.create!(
        organization: recipient.organization,
        actor_membership: actor,
        notifiable: notifiable,
        kind: kind,
        title: title,
        body: body,
        path: path
      )
    end

    def deliver_to(recipients, **attributes)
      Array(recipients).uniq.each { |recipient| deliver(recipient: recipient, **attributes) }
    end

    def path_for(name, *args, **options)
      Rails.application.routes.url_helpers.public_send(name, *args, **options.merge(only_path: true))
    end
  end
end
