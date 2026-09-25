class SupportTicketPolicy < ApplicationPolicy
  def index?
    principal.is_a?(Admin) ? permitted?("support_tickets.console") : Current.membership.present?
  end

  def show?
    if principal.is_a?(Admin)
      record.escalated? && permitted?("support_tickets.console")
    else
      same_organization? && (manager? || record.reporter_membership_id == Current.membership&.id)
    end
  end

  def create?
    principal.is_a?(User) && Current.membership.present? && same_organization?
  end

  def reply? = show? && !record.resolved?
  def update? = principal.is_a?(Admin) ? show? : same_organization? && manager?
  def escalate? = !principal.is_a?(Admin) && update? && !record.escalated?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if principal.is_a?(Admin)
        principal.can?("support_tickets.console") ? scope.escalated : scope.none
      elsif Current.membership&.permission?("support_tickets.manage")
        scope.where(organization: Current.organization)
      else
        scope.where(organization: Current.organization, reporter_membership: Current.membership)
      end
    end
  end

  private
    def same_organization? = record.organization_id == Current.organization&.id
    def manager? = Current.membership&.permission?("support_tickets.manage")
end
