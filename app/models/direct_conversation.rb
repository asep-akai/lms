class DirectConversation < ApplicationRecord
  belongs_to :organization
  belongs_to :participant_one_membership, class_name: "Membership"
  belongs_to :participant_two_membership, class_name: "Membership"
  has_many :direct_messages, -> { chronological }, dependent: :destroy, inverse_of: :direct_conversation

  validates :participant_one_membership_id, comparison: { less_than: :participant_two_membership_id }
  validate :participants_belong_to_organization

  scope :for_participant, ->(membership) {
    where(participant_one_membership: membership).or(where(participant_two_membership: membership))
  }
  scope :recent_first, -> { order(Arel.sql("COALESCE(last_message_at, created_at) DESC")) }

  def self.between!(first_membership, second_membership)
    conversation = between(first_membership, second_membership)
    create_or_find_by!(conversation.attributes.slice(
      "organization_id",
      "participant_one_membership_id",
      "participant_two_membership_id"
    ))
  end

  def self.between(first_membership, second_membership)
    first, second = [ first_membership, second_membership ].sort_by(&:id)
    new(
      organization: first.organization,
      participant_one_membership: first,
      participant_two_membership: second
    )
  end

  def participant?(membership)
    membership&.id.in?([ participant_one_membership_id, participant_two_membership_id ])
  end

  def other_participant(membership)
    if participant_one_membership_id == membership&.id
      participant_two_membership
    elsif participant_two_membership_id == membership&.id
      participant_one_membership
    end
  end

  def unread_for?(membership)
    return false unless participant?(membership) && last_message_at

    last_read_at = participant_one_membership_id == membership.id ? participant_one_last_read_at : participant_two_last_read_at
    last_read_at.nil? || last_message_at > last_read_at
  end

  def mark_read_by!(membership, at: Time.current)
    return unless participant?(membership)

    attribute = participant_one_membership_id == membership.id ? :participant_one_last_read_at : :participant_two_last_read_at
    update_column(attribute, at)
  end

  private
    def participants_belong_to_organization
      participants = [ participant_one_membership, participant_two_membership ].compact
      return if participants.all? { |participant| participant.organization_id == organization_id }

      errors.add(:base, "Participants must belong to this organization")
    end
end
