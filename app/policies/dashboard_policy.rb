class DashboardPolicy < ApplicationPolicy
  def show?
    principal.is_a?(User) && principal.active?
  end
end
