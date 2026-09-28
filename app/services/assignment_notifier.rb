class AssignmentNotifier
  def self.assigned(assignment)
    assignment.recipients.find_each do |recipient|
      AssignmentMailer.with(assignment: assignment, recipient: recipient).assigned.deliver_later
      notify_student(recipient.student_membership, assignment, "assignment_created", "New assignment", assignment.title)
    end
  end

  def self.updated(assignment, added_students:, removed_students:)
    added_students.each do |student|
      AssignmentMailer.with(assignment: assignment, student: student.user).assigned.deliver_later
      notify_student(student, assignment, "assignment_created", "New assignment", assignment.title)
    end

    removed_students.each do |student|
      AssignmentMailer.with(assignment: assignment, student: student.user).removed.deliver_later
    end

    added_ids = added_students.map(&:id)
    assignment.student_memberships.where.not(id: added_ids).includes(:user).find_each do |student|
      AssignmentMailer.with(assignment: assignment, student: student.user).updated.deliver_later
      notify_student(student, assignment, "assignment_updated", "Assignment updated", assignment.title)
    end
  end

  def self.cancelled(assignment)
    assignment.student_memberships.includes(:user).find_each do |student|
      AssignmentMailer.with(assignment: assignment, student: student.user).cancelled.deliver_later
      notify_student(student, assignment, "assignment_cancelled", "Assignment cancelled", assignment.title)
    end
  end

  def self.submitted(submission)
    AssignmentMailer.with(submission: submission).submitted.deliver_later
    assignment = submission.assignment
    InAppNotifier.deliver(
      recipient: assignment.teacher_membership,
      kind: "assignment_submitted",
      title: "Assignment submitted",
      body: "#{submission.student_membership.user.name} submitted #{assignment.title}.",
      path: assignment_path(assignment),
      actor: submission.student_membership,
      notifiable: submission
    )
  end

  def self.commented(submission)
    AssignmentMailer.with(submission: submission).commented.deliver_later
    assignment = submission.assignment
    notify_student(
      submission.student_membership,
      assignment,
      "assignment_commented",
      "Teacher commented on your assignment",
      assignment.title
    )
  end

  def self.notify_student(student, assignment, kind, title, body)
    InAppNotifier.deliver(
      recipient: student,
      kind: kind,
      title: title,
      body: body,
      path: assignment_path(assignment),
      notifiable: assignment
    )
  end

  def self.assignment_path(assignment)
    InAppNotifier.path_for(:organization_assignment_path, assignment.organization, assignment)
  end

  private_class_method :notify_student, :assignment_path
end
