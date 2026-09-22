class Organizations::AssignmentSubmissionsController < Organizations::BaseController
  before_action :set_assignment

  def update
    recipient = @assignment.recipients.find_by!(student_membership: Current.membership)
    submission = recipient.submission || recipient.build_submission
    authorize submission
    submission.assign_attributes(submission_params)

    if params[:submit_assignment] == "1"
      submit_submission(submission)
    elsif submission.save
      redirect_to organization_assignment_path(Current.organization, @assignment), notice: "Draft saved."
    else
      render_student_assignment(submission)
    end
  end

  def comment
    recipient = @assignment.recipients.find(params[:recipient_id])
    submission = recipient.submission || raise(ActiveRecord::RecordNotFound)
    authorize submission, :comment?
    submission.comment!(params.require(:assignment_submission).require(:teacher_comment))
    AssignmentNotifier.commented(submission)
    AuditRecorder.record!(action: "assignment.commented", auditable: @assignment, metadata: { student: recipient.student_membership.user.name })
    redirect_to organization_assignment_path(Current.organization, @assignment), notice: "Comment sent to the student."
  rescue ActiveRecord::RecordInvalid, ArgumentError => error
    redirect_to organization_assignment_path(Current.organization, @assignment), alert: error.message
  end

  def download_document
    submission = @assignment.submissions.find(params[:submission_id])
    authorize submission, :download?
    attachment = submission.documents_attachments.find(params[:attachment_id])
    response.headers["Cache-Control"] = "private, no-store"
    send_data attachment.download,
      filename: attachment.filename.to_s,
      type: "application/octet-stream",
      disposition: "attachment"
  end

  private
    def set_assignment
      @assignment = policy_scope(Assignment).find(params[:assignment_id])
    end

    def submission_params
      params.require(:assignment_submission).permit(:body, documents: [])
    end

    def submit_submission(submission)
      submission.submit!
      AssignmentNotifier.submitted(submission)
      AuditRecorder.record!(
        action: "assignment.submitted",
        auditable: @assignment,
        actor: Current.user,
        metadata: { student: submission.student_membership.user.name, late: submission.late? }
      )
      redirect_to organization_assignment_path(Current.organization, @assignment), notice: "Assignment submitted."
    rescue ActiveRecord::RecordInvalid, ArgumentError
      render_student_assignment(submission)
    end

    def render_student_assignment(submission)
      @recipient = submission.assignment_recipient
      @submission = submission
      render "organizations/assignments/show", status: :unprocessable_entity
    end
end
