class UserPolicy < ApplicationPolicy
  def index? = permitted?("users.index")
  def create? = permitted?("users.create")
  def update? = permitted?("users.update")
  def destroy? = permitted?("users.destroy")

  class Scope < ApplicationPolicy::Scope
    def resolve
      principal.can?("users.index") ? scope.all : scope.none
    end
  end
end
