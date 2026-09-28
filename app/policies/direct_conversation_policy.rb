class DirectConversationPolicy < ApplicationPolicy
  def index?
    Current.membership&.active?
  end

  def show?
    return false unless record.organization == Current.organization && record.participant?(Current.membership)

    DirectContactDirectory.new(Current.membership).connected?(record.other_participant(Current.membership))
  end

  def create?
    return false unless record.organization == Current.organization
    return false unless record.participant?(Current.membership)

    contact = record.other_participant(Current.membership)
    DirectContactDirectory.new(Current.membership).connected?(contact)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless Current.membership

      contact_ids = DirectContactDirectory.new(Current.membership).contact_ids
      conversations = scope.where(organization: Current.organization).for_participant(Current.membership)
      conversations.where(participant_one_membership_id: contact_ids)
        .or(conversations.where(participant_two_membership_id: contact_ids))
    end
  end
end
