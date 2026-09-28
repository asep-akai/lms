class DirectMessagePolicy < ApplicationPolicy
  def create?
    DirectConversationPolicy.new(principal, record.direct_conversation).show? &&
      record.sender_membership == Current.membership
  end
end
