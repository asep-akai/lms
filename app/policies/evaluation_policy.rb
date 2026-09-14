class EvaluationPolicy < ApplicationPolicy
  def index? = principal.is_a?(User) && Current.membership&.active? && Current.membership.student?
end
