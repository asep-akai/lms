class AssignmentMailer < ApplicationMailer
  def assigned
    @assignment = params[:assignment]
    @recipient = params[:recipient]
    @student = params[:student] || @recipient.student_membership.user
    @deadline = localized_deadline
    mail(to: @student.email, subject: "New assignment: #{@assignment.title}")
  end

  def updated
    prepare_assignment_and_student
    @deadline = localized_deadline
    mail(to: @student.email, subject: "Assignment updated: #{@assignment.title}")
  end

  def removed
    prepare_assignment_and_student
    mail(to: @student.email, subject: "Assignment removed: #{@assignment.title}")
  end

  def cancelled
    prepare_assignment_and_student
    mail(to: @student.email, subject: "Assignment cancelled: #{@assignment.title}")
  end

  def submitted
    @submission = params[:submission]
    @assignment = @submission.assignment
    @student = @submission.student_membership.user
    @teacher = @assignment.teacher_membership.user
    mail(to: @teacher.email, subject: "Assignment submitted: #{@assignment.title}, #{@student.name}")
  end

  def commented
    @submission = params[:submission]
    @assignment = @submission.assignment
    @student = @submission.student_membership.user
    @teacher = @assignment.teacher_membership.user
    mail(to: @student.email, subject: "New comment on #{@assignment.title}")
  end

  private
    def prepare_assignment_and_student
      @assignment = params[:assignment]
      @student = params[:student]
    end

    def localized_deadline
      @assignment.deadline.in_time_zone(@assignment.organization.timezone)
    end
end
