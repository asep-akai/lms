class DirectMessage < ApplicationRecord
  belongs_to :direct_conversation, touch: :last_message_at
  belongs_to :sender_membership, class_name: "Membership"

  normalizes :body, with: ->(body) { body.to_s.strip }

  validates :body, presence: true, length: { maximum: 5_000 }
  validate :sender_participates_in_conversation

  scope :chronological, -> { order(:created_at, :id) }

  after_create_commit :broadcast_message

  private
    def sender_participates_in_conversation
      return if direct_conversation&.participant?(sender_membership)

      errors.add(:sender_membership, "must participate in the conversation")
    end

    def broadcast_message
      recipient = direct_conversation.other_participant(sender_membership)
      notify_recipient(recipient)
      broadcast_render_to(
        direct_conversation,
        recipient,
        partial: "organizations/direct_messages/broadcast",
        locals: { message: self }
      )
      broadcast_replace_to(
        direct_conversation.organization,
        recipient,
        :direct_conversations,
        target: ActionView::RecordIdentifier.dom_id(direct_conversation),
        partial: "organizations/direct_conversations/conversation",
        locals: { conversation: direct_conversation, membership: recipient }
      )
    end

    def notify_recipient(recipient)
      path = InAppNotifier.path_for(
        :organization_direct_conversation_path,
        direct_conversation.organization,
        direct_conversation
      )
      existing = recipient.notifications.unread.find_by(kind: "direct_message", notifiable: direct_conversation)
      if existing
        existing.update!(
          actor_membership: sender_membership,
          title: "New message from #{sender_membership.user.name}",
          body: body.truncate(180),
          path: path,
          created_at: Time.current
        )
      else
        InAppNotifier.deliver(
          recipient: recipient,
          actor: sender_membership,
          kind: "direct_message",
          title: "New message from #{sender_membership.user.name}",
          body: body.truncate(180),
          path: path,
          notifiable: direct_conversation
        )
      end
    end
end
