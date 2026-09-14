class AdminPolicy < ApplicationPolicy
  def index? = permitted?("admins.index")
  def create? = permitted?("admins.create")
  def update? = permitted?("admins.update")
  def destroy? = permitted?("admins.destroy") && record != principal

  class Scope < ApplicationPolicy::Scope
    def resolve
      principal.can?("admins.index") ? scope.all : scope.none
    end
  end
end
