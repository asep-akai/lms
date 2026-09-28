class Organizations::AssignmentsController < Organizations::BaseController
  before_action :set_assignment, only: %i[show edit update cancel download_document]

  def index
    authorize Assignment
    @query = TableSearch.normalize(params[:query])
    assignments = TableSearch.call(
      policy_scope(Assignment),
      query: @query,
      columns: %w[assignments.title assignments.description]
    )
    assignments = assignments
      .includes({ teacher_membership: :user }, recipients: [ { student_membership: :user }, :submission ])
      .soonest_first
    @pagination, @assignments = paginate(assignments)
  end

  def show
    authorize @assignment
    if Current.membership.student?
      @recipient = @assignment.recipients.includes(submission: { documents_attachments: :blob }).find_by!(student_membership: Current.membership)
      @submission = @recipient.submission || @recipient.build_submission
    else
      @recipients = @assignment.recipients
        .includes({ student_membership: :user }, submission: { documents_attachments: :blob })
        .joins(student_membership: :user)
        .order("users.name")
    end
  end

  def new
    @assignment = Current.organization.assignments.new(teacher_membership: Current.membership)
    authorize @assignment
    load_students
    @selected_student_ids = eligible_students.where(id: params[:student_id]).ids
  end

  def create
    @assignment = Current.organization.assignments.new(assignment_attributes)
    @assignment.teacher_membership = Current.membership
    authorize @assignment
    load_students
    @selected_student_ids = selected_student_ids
    @selected_student_ids.each { |student_id| @assignment.recipients.build(student_membership_id: student_id) }

    if @assignment.save
      AssignmentNotifier.assigned(@assignment)
      AuditRecorder.record!(
        action: "assignment.created",
        auditable: @assignment,
        metadata: { title: @assignment.title, student_count: @assignment.recipients.size, deadline: @assignment.deadline.iso8601 }
      )
      redirect_to organization_assignment_path(Current.organization, @assignment), notice: "Assignment created and students notified."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @assignment
    load_students
    @selected_student_ids = @assignment.student_membership_ids
  end

  def update
    authorize @assignment
    load_students
    @selected_student_ids = selected_student_ids
    previous_attributes = @assignment.attributes.slice("title", "description", "deadline")
    current_recipients = @assignment.recipients.includes(student_membership: :user).index_by(&:student_membership_id)
    removed_recipients = current_recipients.values_at(*(current_recipients.keys - @selected_student_ids)).compact

    if removed_recipients.any? { |recipient| recipient.submission.present? }
      @assignment.assign_attributes(assignment_attributes)
      @assignment.errors.add(:students, "with saved work cannot be removed")
      return render :edit, status: :unprocessable_entity
    end

    added_student_ids = @selected_student_ids - current_recipients.keys
    added_students = @students.select { |student| student.id.in?(added_student_ids) }
    removed_students = removed_recipients.map(&:student_membership)

    Assignment.transaction do
      @assignment.assign_attributes(assignment_attributes)
      removed_recipients.each(&:destroy!)
      added_student_ids.each { |student_id| @assignment.recipients.build(student_membership_id: student_id) }
      @assignment.save!
      @assignment.document.purge if remove_document? && assignment_params[:document].blank?
    end

    AssignmentNotifier.updated(@assignment, added_students: added_students, removed_students: removed_students)
    AuditRecorder.record!(
      action: "assignment.updated",
      auditable: @assignment,
      metadata: { student_count: @assignment.recipients.size },
      changes: previous_attributes.to_h { |key, value| [ key, [ value, @assignment.public_send(key) ] ] }
    )
    redirect_to organization_assignment_path(Current.organization, @assignment), notice: "Assignment updated and students notified."
  rescue ActiveRecord::RecordInvalid => error
    @assignment.errors.merge!(error.record.errors) unless error.record == @assignment
    @assignment.recipients.reset
    render :edit, status: :unprocessable_entity
  end

  def cancel
    authorize @assignment, :cancel?
    @assignment.update!(cancelled_at: Time.current)
    AssignmentNotifier.cancelled(@assignment)
    AuditRecorder.record!(
      action: "assignment.cancelled",
      auditable: @assignment,
      metadata: { title: @assignment.title, student_count: @assignment.recipients.size }
    )
    redirect_to organization_assignment_path(Current.organization, @assignment), notice: "Assignment cancelled. Students can no longer submit work."
  end

  def download_document
    authorize @assignment, :show?
    return head :not_found unless @assignment.document.attached?

    send_attachment(@assignment.document)
  end

  private
    def set_assignment
      @assignment = policy_scope(Assignment).find(params[:id])
    end

    def load_students
      available_ids = eligible_students.ids
      available_ids |= @assignment.student_membership_ids if @assignment.persisted?
      @students = Current.organization.memberships.where(id: available_ids).includes(:user).joins(:user).order("users.name")
    end

    def eligible_students
      Current.organization.memberships.active.taught_by(Current.membership)
    end

    def assignment_params
      params.require(:assignment).permit(:title, :description, :deadline, :document, :remove_document, student_ids: [])
    end

    def assignment_attributes
      attributes = assignment_params.except(:student_ids, :deadline, :remove_document)
      attributes[:deadline] = normalized_deadline
      attributes
    end

    def normalized_deadline
      parsed_deadline = parse_local_time(assignment_params[:deadline])
      return parsed_deadline unless @assignment&.persisted? && parsed_deadline

      displayed_deadline = @assignment.deadline.in_time_zone(Current.organization.timezone).change(sec: 0)
      parsed_deadline == displayed_deadline ? @assignment.deadline : parsed_deadline
    end

    def selected_student_ids
      requested_ids = Array(assignment_params[:student_ids]).filter_map { |id| Integer(id, exception: false) }
      requested_ids & @students.map(&:id)
    end

    def remove_document?
      ActiveModel::Type::Boolean.new.cast(assignment_params[:remove_document])
    end

    def parse_local_time(value)
      ActiveSupport::TimeZone[Current.organization.timezone].parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def send_attachment(attachment)
      response.headers["Cache-Control"] = "private, no-store"
      send_data attachment.download,
        filename: attachment.filename.to_s,
        type: "application/octet-stream",
        disposition: "attachment"
    end
end
