class Organizations::StudentsController < Organizations::BaseController
  before_action :set_student, only: %i[show enrollment enroll reschedule_quota update_reschedule_quota]
  helper_method :quota_return_path

  def index
    authorize :student, :index?
    @query = TableSearch.normalize(params[:query])
    students = visible_students.includes(:user, :course_enrollments).joins(:user)
    students = TableSearch.call(
      students,
      query: @query,
      columns: %w[users.name users.email memberships.status]
    ).order("users.name")
    @pagination, @students = paginate(students)
  end

  def show
    authorize @student, policy_class: StudentPolicy
    load_progress
    load_quiz_attempts
    load_certificates
  end

  def enrollment
    authorize @student, :show?, policy_class: StudentPolicy
    authorize Course, :update_enrollments?
    load_available_courses
    render_modal(partial: "organizations/students/enrollment_form", locals: { student: @student }) if modal_request?
  end

  def enroll
    authorize @student, :show?, policy_class: StudentPolicy
    course = Current.organization.courses.find(params.require(:course_id))
    authorize course, :update_enrollments?

    unless @student.active?
      return redirect_to organization_students_path(Current.organization), alert: "Reactivate this student before enrolling them in a course."
    end

    previous_students = course.enrolled_memberships.includes(:user).map { |membership| student_label(membership) }.sort
    course.course_enrollments.create!(membership: @student)
    AuditRecorder.record!(
      action: "course.enrollments_updated",
      auditable: course,
      metadata: { name: course.name, enrollment_count: course.course_enrollments.count },
      changes: { enrolled_students: [ previous_students, (previous_students + [ student_label(@student) ]).uniq.sort ] }
    )
    redirect_to organization_students_path(Current.organization), notice: "Student enrolled in #{course.name}."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to organization_students_path(Current.organization), alert: error.record.errors.full_messages.to_sentence
  end

  def reschedule_quota
    authorize_quota_management!
    render_modal(partial: "organizations/students/reschedule_quota_form", locals: { student: @student }) if modal_request?
  end

  def update_reschedule_quota
    authorize_quota_management!
    previous_quota = @student.reschedule_quota

    if @student.update(reschedule_quota_params)
      AuditRecorder.record!(
        action: "membership.reschedule_quota_updated",
        auditable: @student,
        changes: { reschedule_quota: [ previous_quota, @student.reschedule_quota ] }
      )
      redirect_to quota_return_path, notice: "Reschedule quota updated."
    else
      if modal_request?
        render_modal(
          partial: "organizations/students/reschedule_quota_form",
          locals: { student: @student },
          status: :unprocessable_entity
        )
      else
        render :reschedule_quota, status: :unprocessable_entity
      end
    end
  end

  private
    def authorize_quota_management!
      authorize @student, :update?
      raise Pundit::NotAuthorizedError unless Current.membership.organization_admin?
    end

    def reschedule_quota_params
      params.require(:membership).permit(:reschedule_quota)
    end

    def quota_return_path
      if params[:from] == "student"
        organization_student_path(Current.organization, @student)
      else
        organization_students_path(Current.organization)
      end
    end

    def load_progress
      @courses = @student.enrolled_courses.includes(course_contents: :contentable).ordered
      @course_progress = CourseProgress.for(courses: @courses, memberships: [ @student ])
    end

    def load_available_courses
      enrolled_course_ids = @student.course_enrollments.select(:course_id)
      @available_courses = Current.organization.courses.where.not(id: enrolled_course_ids).ordered
    end

    def set_student
      @student = visible_students.find(params[:id])
    end

    def visible_students
      policy_scope(Membership, policy_scope_class: StudentPolicy::Scope)
    end

    def load_quiz_attempts
      @quiz_attempts = @student.quiz_attempts
        .includes(
          :answer_overrides,
          { quiz: [ :course, { questions: :answer_options } ] },
          { answers: [ :quiz_answer_option, { audio_response_attachment: :blob } ] }
        )
        .order(Arel.sql("COALESCE(reviewed_at, submitted_at, last_activity_at, started_at) DESC"))
      @gradings_by_attempt_id = @quiz_attempts.filter(&:reviewed?).to_h do |attempt|
        [ attempt.id, QuizAttemptGrader.new(attempt) ]
      end
    end

    def load_certificates
      @certificates = @student.received_certificates.published.newest_first
    end

    def student_label(membership)
      "#{membership.user.name} (#{membership.user.email})"
    end
end
