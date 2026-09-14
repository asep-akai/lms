class AuditEventPolicy < ApplicationPolicy
  def index? = permitted?("audit_events.index")

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: Current.organization)
    end
  end
end
