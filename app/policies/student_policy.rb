class StudentPolicy < ApplicationPolicy
  def index? = permitted?("students.index")

  def show?
    permitted?("students.show") && record.organization == Current.organization && record.student?
  end
end
