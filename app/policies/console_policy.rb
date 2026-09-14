class ConsolePolicy < ApplicationPolicy
  def access?
    principal.is_a?(Admin) && principal.can?("console.access")
  end
end
