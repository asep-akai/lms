class OrganizationPolicy < ApplicationPolicy
  def index?
    principal.is_a?(Admin) ? permitted?("organizations.index") : principal.is_a?(User)
  end

  def show?
    return permitted?("console.access") if principal.is_a?(Admin)

    principal.memberships.active.exists?(organization: record) && record.active?
  end

  def create?
    principal.is_a?(Admin) && permitted?("organizations.create")
  end

  def update?
    principal.is_a?(Admin) ? permitted?("organizations.update") : permitted?("organization.update")
  end

  def destroy? = principal.is_a?(Admin) && permitted?("organizations.update")

  class Scope < ApplicationPolicy::Scope
    def resolve
      if principal.is_a?(Admin)
        principal.can?("organizations.index") ? scope.all : scope.none
      else
        scope.active.joins(:memberships).merge(Membership.active).where(memberships: { user_id: principal.id }).distinct
      end
    end
  end
end
