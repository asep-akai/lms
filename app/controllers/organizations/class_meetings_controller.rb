class Organizations::ClassMeetingsController < Organizations::BaseController
  before_action :set_class_meeting, only: %i[show edit update destroy]
  before_action :set_navigation_context, only: %i[show edit update destroy]
  before_action :load_assignment_options, only: %i[new create edit update]

  def index
    authorize ClassMeeting
    meetings = policy_scope(ClassMeeting)
    @calendar = ClassMeetingCalendar.new(
      scope: meetings,
      month: params[:month],
      time_zone: Current.organization.timezone
    )
    @class_meetings = meetings
      .upcoming
      .includes(teacher_membership: :user, student_memberships: :user)
      .chronological
  end

  def history
    authorize ClassMeeting, :index?
    @query = params[:query].to_s.squish.first(200)
    @class_meetings = ClassMeetingHistoryQuery.call(
      scope: class_history_scope,
      membership: Current.membership,
      query: @query
    )
    visible_feedbacks = policy_scope(ClassMeetingFeedback)
      .where(class_meeting_id: @class_meetings.map(&:id))
      .includes(author_membership: :user)
      .to_a
    @own_feedbacks_by_meeting_id = visible_feedbacks
      .select { |feedback| feedback.author_membership_id == Current.membership.id }
      .index_by(&:class_meeting_id)
    @received_feedbacks_by_meeting_id = visible_feedbacks
      .reject { |feedback| feedback.author_membership_id == Current.membership.id }
      .group_by(&:class_meeting_id)
  end

  def day
    authorize ClassMeeting, :index?
    @date = calendar_date
    @class_meetings = policy_scope(ClassMeeting)
      .where(starts_at: local_day_range(@date))
      .includes(teacher_membership: :user, student_memberships: :user)
      .chronological

    render_modal(
      partial: "organizations/class_meetings/day_details",
      locals: { date: @date, class_meetings: @class_meetings }
    ) if modal_request?
  end

  def show
    authorize @class_meeting
  end

  def new
    @class_meeting = Current.organization.class_meetings.new
    authorize @class_meeting
  end

  def create
    @class_meeting = Current.organization.class_meetings.new
    authorize @class_meeting
    assign_form_attributes

    if save_with_sequence_lock
      ClassMeetingNotifier.call(@class_meeting)
      AuditRecorder.record!(
        action: "class_meeting.created",
        auditable: @class_meeting,
        metadata: audit_metadata
      )
      redirect_to organization_class_meeting_path(Current.organization, @class_meeting), notice: "Class meeting scheduled. Email notifications have been queued."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @class_meeting
  end

  def update
    authorize @class_meeting
    assign_form_attributes

    if save_with_sequence_lock
      AuditRecorder.record!(
        action: "class_meeting.updated",
        auditable: @class_meeting,
        metadata: audit_metadata,
        changes: @class_meeting.saved_changes.slice("subject", "topic", "starts_at", "delivery_mode", "teacher_membership_id", "meeting_number")
      )
      redirect_to organization_class_meeting_path(Current.organization, @class_meeting, **@navigation_params), notice: "Class meeting updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @class_meeting
    metadata = audit_metadata
    @class_meeting.destroy!
    AuditRecorder.record!(action: "class_meeting.deleted", auditable: @class_meeting, metadata: metadata)
    redirect_to @back_path, notice: "Class meeting deleted."
  end

  private
    def set_class_meeting
      @class_meeting = Current.organization.class_meetings
        .includes(teacher_membership: :user, student_memberships: :user)
        .find(params[:id])
    end

    def calendar_date
      Date.iso8601(params[:date])
    rescue Date::Error
      raise ActiveRecord::RecordNotFound
    end

    def set_navigation_context
      if params[:from] == "history"
        history_query = params[:history_query].to_s.squish.first(200).presence
        @navigation_params = { from: "history", history_query: history_query }.compact
        @back_label = "Back to class history"
        @back_path = history_organization_class_meetings_path(Current.organization, query: history_query)
      else
        month = valid_month(params[:month])
        @navigation_params = { month: month }.compact
        @back_label = "Back to classes"
        @back_path = organization_class_meetings_path(Current.organization, month: month)
      end
    end

    def valid_month(value)
      return unless value.to_s.match?(/\A\d{4}-\d{2}\z/)

      Date.strptime("#{value}-01", "%Y-%m-%d").strftime("%Y-%m")
    rescue Date::Error
      nil
    end

    def local_day_range(date)
      zone = ActiveSupport::TimeZone[Current.organization.timezone]
      zone.local(date.year, date.month, date.day).utc...zone.local(date.year, date.month, date.day).tomorrow.utc
    end

    def class_history_scope
      scope = policy_scope(ClassMeeting)
      return scope unless Current.membership.student? || Current.membership.teacher?

      scope.assigned_to(Current.membership)
    end

    def load_assignment_options
      @teachers = memberships_with_role("teacher")
      @students = memberships_with_role("student")
    end

    def memberships_with_role(role_key)
      Current.organization.memberships.active
        .joins(user: { role_assignments: :role })
        .where(roles: { organization_id: Current.organization.id, key: role_key })
        .distinct
        .includes(:user)
        .joins(:user)
        .order("users.name", "users.email")
    end

    def assign_form_attributes
      attributes = class_meeting_params
      student_ids = attributes.delete(:student_membership_ids)
      local_starts_at = attributes.delete(:starts_at)
      attributes[:starts_at] = parse_local_time(local_starts_at)
      @class_meeting.assign_attributes(attributes)
      @selected_student_memberships = @students.where(id: student_ids).to_a
    end

    def class_meeting_params
      params.require(:class_meeting).permit(
        :teacher_membership_id,
        :subject,
        :topic,
        :starts_at,
        :delivery_mode,
        :meeting_url,
        student_membership_ids: []
      )
    end

    def parse_local_time(value)
      ActiveSupport::TimeZone[Current.organization.timezone].parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def save_with_sequence_lock
      saved = false
      Current.organization.with_lock do
        @class_meeting.student_memberships = @selected_student_memberships
        saved = @class_meeting.save
        raise ActiveRecord::Rollback unless saved
      end
      saved
    end

    def audit_metadata
      {
        class_subject: @class_meeting.subject,
        topic: @class_meeting.topic,
        meeting_number: @class_meeting.meeting_number,
        teacher: @class_meeting.teacher_membership.user.name,
        student_count: @class_meeting.student_memberships.size
      }
    end
end
