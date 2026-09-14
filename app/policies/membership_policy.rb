class MembershipPolicy < ApplicationPolicy
  def index? = permitted?("memberships.index")
  def create? = permitted?("memberships.create")
  def update? = permitted?("memberships.update")
  def destroy? = permitted?("memberships.destroy")

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: Current.organization)
    end
  end
end
