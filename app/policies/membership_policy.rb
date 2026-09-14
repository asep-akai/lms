class MembershipPolicy < ApplicationPolicy
  def index? = permitted?("memberships.index")
  def create? = permitted?("memberships.create")
  def update? = permitted?("memberships.update") && protected_membership_manageable?
  def destroy? = permitted?("memberships.destroy") && protected_membership_manageable?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: Current.organization)
    end
  end

  private
    def protected_membership_manageable?
      !record.organization_admin? || principal.organization_admin?(record.organization)
    end
end
