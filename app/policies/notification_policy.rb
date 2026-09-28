class NotificationPolicy < ApplicationPolicy
  def index? = Current.membership&.active? && Current.membership.notification_recipient?

  def show?
    record.organization == Current.organization && record.recipient_membership == Current.membership
  end

  def mark_all_read? = index?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless Current.membership

      scope.where(organization: Current.organization, recipient_membership: Current.membership)
    end
  end
end
