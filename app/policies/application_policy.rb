# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :principal, :record

  def initialize(principal, record)
    @principal = principal
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  private
    def permitted?(key, organization: policy_organization)
      return false unless principal
      return principal.can?(key) if principal.is_a?(Admin)
      return false unless organization

      principal.can?(key, organization: organization)
    end

    def policy_organization
      return record if record.is_a?(Organization)
      return record.organization if record.respond_to?(:organization)

      Current.organization
    end

  class Scope
    def initialize(principal, scope)
      @principal = principal
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :principal, :scope
  end
end
