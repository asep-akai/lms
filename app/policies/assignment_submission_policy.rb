class AssignmentSubmissionPolicy < ApplicationPolicy
  def update?
    Current.membership&.student? &&
      record.student_membership == Current.membership &&
      !record.assignment.cancelled? &&
      !record.submitted?
  end

  def comment?
    record.submitted? && AssignmentPolicy.new(principal, record.assignment).review?
  end

  def download?
    return true if record.student_membership == Current.membership

    AssignmentPolicy.new(principal, record.assignment).review?
  end
end
