class Organizations::ClassMeetingFeedbacksController < Organizations::BaseController
  before_action :set_class_meeting, except: :admin_index
  before_action :set_feedback, only: :show
  before_action :set_navigation_context, except: :admin_index

  def admin_index
    authorize ClassMeetingFeedback, :index?
    load_filter_options
    @filters = normalized_filters
    feedbacks = ClassMeetingFeedbackQuery.call(
      scope: policy_scope(ClassMeetingFeedback),
      **@filters.slice(:query, :author_role, :rating, :teacher_membership_id, :student_membership_id)
    )
    @pagination, @feedbacks = paginate(feedbacks)
  end

  def index
    authorize @class_meeting, :show?
    @feedbacks = received_feedbacks
    render_modal(
      partial: "organizations/class_meeting_feedbacks/list",
      locals: { class_meeting: @class_meeting, feedbacks: @feedbacks }
    ) if modal_request?
  end

  def show
    authorize @feedback
    render_modal(
      partial: "organizations/class_meeting_feedbacks/details",
      locals: { feedback: @feedback }
    ) if modal_request?
  end

  def new
    @feedback = @class_meeting.feedbacks.new(
      author_membership: Current.membership,
      author_role: @class_meeting.feedback_role_for(Current.membership)
    )
    authorize @feedback
    render_modal(
      partial: "organizations/class_meeting_feedbacks/form",
      locals: { class_meeting: @class_meeting, feedback: @feedback }
    ) if modal_request?
  end

  def create
    @feedback = @class_meeting.feedbacks.new(
      feedback_params.merge(
        author_membership: Current.membership,
        author_role: @class_meeting.feedback_role_for(Current.membership)
      )
    )
    authorize @feedback

    if @feedback.save
      notify_feedback_recipients
      AuditRecorder.record!(
        action: "class_meeting.feedback_submitted",
        auditable: @feedback,
        metadata: {
          class_subject: @class_meeting.subject,
          meeting_number: @class_meeting.meeting_number,
          author_role: @feedback.author_role,
          rating: @feedback.rating
        }
      )
      redirect_to @back_path, notice: "Feedback submitted."
    elsif modal_request?
      render_modal(
        partial: "organizations/class_meeting_feedbacks/form",
        locals: { class_meeting: @class_meeting, feedback: @feedback },
        status: :unprocessable_entity
      )
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to @back_path, alert: "You have already submitted feedback for this class."
  end

  private
    def set_class_meeting
      @class_meeting = Current.organization.class_meetings
        .includes(teacher_membership: :user, student_memberships: :user)
        .find(params[:class_meeting_id])
    end

    def set_feedback
      @feedback = policy_scope(@class_meeting.feedbacks)
        .includes(author_membership: :user)
        .find(params[:id])
    end

    def set_navigation_context
      if params[:from] == "feedback"
        @back_label = "Back to feedback"
        @back_path = organization_class_feedback_path(Current.organization, **admin_filter_params)
      else
        query = params[:history_query].to_s.squish.first(200).presence
        @back_label = "Back to class history"
        @back_path = history_organization_class_meetings_path(Current.organization, query: query)
      end
    end

    def received_feedbacks
      feedbacks = policy_scope(@class_meeting.feedbacks).includes(author_membership: :user).order(created_at: :asc)
      if @class_meeting.teacher_membership_id == Current.membership.id
        feedbacks.student_feedbacks
      else
        feedbacks.teacher_feedbacks
      end
    end

    def notify_feedback_recipients
      recipients = if @feedback.author_role == "teacher"
        @class_meeting.student_memberships
      else
        [ @class_meeting.teacher_membership ]
      end
      InAppNotifier.deliver_to(
        recipients,
        kind: "class_feedback",
        title: "New class feedback",
        body: "#{@class_meeting.subject}: #{@class_meeting.topic}",
        path: InAppNotifier.path_for(:organization_class_meeting_path, Current.organization, @class_meeting),
        notifiable: @feedback
      )
    end

    def feedback_params
      allowed_fields = if @class_meeting.teacher_membership_id == Current.membership.id
        %i[rating internal_feedback feedback_to_student topics_discussed next_topics]
      else
        %i[rating comment]
      end
      params.require(:class_meeting_feedback).permit(*allowed_fields)
    end

    def load_filter_options
      @teachers = memberships_with_role("teacher")
      @students = memberships_with_role("student")
    end

    def normalized_filters
      {
        query: params[:query].to_s.squish.first(200).presence,
        author_role: params[:author_role].to_s.in?(ClassMeetingFeedback::AUTHOR_ROLES) ? params[:author_role] : nil,
        rating: params[:rating].to_i.in?(1..5) ? params[:rating].to_i : nil,
        teacher_membership_id: @teachers.find { |membership| membership.id == params[:teacher_id].to_i }&.id,
        student_membership_id: @students.find { |membership| membership.id == params[:student_id].to_i }&.id
      }
    end

    def admin_filter_params
      params.permit(:query, :author_role, :rating, :teacher_id, :student_id).to_h.compact_blank
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
end
