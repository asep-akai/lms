class RolePolicy < ApplicationPolicy
  def index? = permitted?("roles.index")
  def create? = permitted?("roles.create")
  def update? = record.editable? && permitted?("roles.update")
  def destroy? = record.editable? && permitted?("roles.destroy")

  class Scope < ApplicationPolicy::Scope
    def resolve
      principal.is_a?(Admin) ? scope.where(organization: nil) : scope.where(organization: Current.organization)
    end
  end
end
