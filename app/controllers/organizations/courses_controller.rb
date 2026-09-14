class Organizations::CoursesController < Organizations::BaseController
  before_action :set_course, only: %i[show edit update destroy enrollments update_enrollments]

  def index
    authorize Course
    @courses = policy_scope(Course).ordered
  end

  def show
    authorize @course
  end

  def new
    @course = Current.organization.courses.new
    authorize @course
  end

  def create
    @course = Current.organization.courses.new(course_params)
    authorize @course

    if @course.save
      AuditRecorder.record!(action: "course.created", auditable: @course, metadata: { name: @course.name })
      redirect_to organization_course_path(Current.organization, @course), notice: "Course created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @course
  end

  def update
    authorize @course

    if @course.update(course_params)
      AuditRecorder.record!(
        action: "course.updated",
        auditable: @course,
        metadata: { name: @course.name },
        changes: @course.saved_changes.slice("name", "description")
      )
      redirect_to organization_course_path(Current.organization, @course), notice: "Course updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @course
    name = @course.name
    @course.destroy!
    AuditRecorder.record!(action: "course.deleted", auditable: @course, metadata: { name: name })
    redirect_to organization_courses_path(Current.organization), notice: "Course deleted."
  end

  def enrollments
    authorize @course, :enrollments?
    load_students
  end

  def update_enrollments
    authorize @course, :update_enrollments?
    previous_students = enrolled_student_labels
    memberships = eligible_students.includes(:user).where(id: enrollment_params[:membership_ids]).to_a

    CourseEnrollment.transaction do
      @course.course_enrollments.where.not(membership: memberships).destroy_all
      memberships.each { |membership| @course.course_enrollments.find_or_create_by!(membership: membership) }
      AuditRecorder.record!(
        action: "course.enrollments_updated",
        auditable: @course,
        metadata: { name: @course.name, enrollment_count: memberships.size },
        changes: { enrolled_students: [ previous_students, memberships.map { |membership| student_label(membership) }.sort ] }
      )
    end

    redirect_to organization_course_path(Current.organization, @course), notice: "Course enrollments updated."
  rescue ActiveRecord::RecordInvalid => error
    @course.errors.add(:base, error.record.errors.full_messages.to_sentence)
    load_students
    render :enrollments, status: :unprocessable_entity
  end

  private
    def set_course
      @course = Current.organization.courses.find(params[:id])
    end

    def course_params
      params.require(:course).permit(:name, :description)
    end

    def enrollment_params
      params.fetch(:course, {}).permit(membership_ids: [])
    end

    def load_students
      @students = eligible_students.includes(:user).joins(:user).order("users.name")
      @enrolled_membership_ids = @course.course_enrollments.pluck(:membership_id)
    end

    def eligible_students
      Current.organization.memberships.active
        .joins(user: { role_assignments: :role })
        .where(roles: { organization_id: Current.organization.id, key: "student" })
        .distinct
    end

    def enrolled_student_labels
      @course.enrolled_memberships.includes(:user).map { |membership| student_label(membership) }.sort
    end

    def student_label(membership)
      "#{membership.user.name} (#{membership.user.email})"
    end
end
