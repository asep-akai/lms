class Organizations::StudentsController < Organizations::BaseController
  before_action :set_student, only: %i[show enrollment enroll]

  def index
    authorize :student, :index?
    @query = TableSearch.normalize(params[:query])
    students = visible_students.includes(:user, :course_enrollments).joins(:user)
    @students = TableSearch.call(
      students,
      query: @query,
      columns: %w[users.name users.email memberships.status]
    ).order("users.name")
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

  private
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
        .includes({ quiz: [ :course, { questions: :answer_options } ] }, { answers: :quiz_answer_option }, :answer_overrides)
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
