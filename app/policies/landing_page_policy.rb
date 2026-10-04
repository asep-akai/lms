class LandingPagePolicy < ApplicationPolicy
  def show?
    edit? || publish?
  end

  def edit?
    principal.is_a?(Admin) && permitted?("website.edit")
  end

  alias_method :update?, :edit?
  alias_method :preview?, :show?

  def publish?
    principal.is_a?(Admin) && permitted?("website.publish")
  end

  alias_method :unpublish?, :publish?
end
