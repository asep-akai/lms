class AssignmentNotifier
  def self.assigned(assignment)
    assignment.recipients.find_each do |recipient|
      AssignmentMailer.with(assignment: assignment, recipient: recipient).assigned.deliver_later
    end
  end

  def self.updated(assignment, added_students:, removed_students:)
    added_students.each do |student|
      AssignmentMailer.with(assignment: assignment, student: student.user).assigned.deliver_later
    end

    removed_students.each do |student|
      AssignmentMailer.with(assignment: assignment, student: student.user).removed.deliver_later
    end

    added_ids = added_students.map(&:id)
    assignment.student_memberships.where.not(id: added_ids).includes(:user).find_each do |student|
      AssignmentMailer.with(assignment: assignment, student: student.user).updated.deliver_later
    end
  end

  def self.cancelled(assignment)
    assignment.student_memberships.includes(:user).find_each do |student|
      AssignmentMailer.with(assignment: assignment, student: student.user).cancelled.deliver_later
    end
  end

  def self.submitted(submission)
    AssignmentMailer.with(submission: submission).submitted.deliver_later
  end

  def self.commented(submission)
    AssignmentMailer.with(submission: submission).commented.deliver_later
  end
end
