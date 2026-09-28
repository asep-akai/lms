class Organizations::CoursesController < Organizations::BaseController
  before_action :set_course, only: %i[show edit update destroy enrollments update_enrollments move_content move_content_to_section]

  def index
    authorize Course
    @pagination, @courses = paginate(policy_scope(Course).ordered)
    load_course_progress(@courses) if Current.membership&.student?
  end

  def show
    authorize @course
    load_course_contents
    load_course_progress([ @course ]) if Current.membership&.student?
    load_student_progress if policy(:student).index?
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

  def move_content
    authorize @course, :arrange_contents?
    content = @course.course_contents.find(params[:content_id])

    @course.with_lock do
      contents = content.course_section.course_contents.ordered_within_section.lock.to_a
      current_index = contents.index(content)
      target_index = params[:direction] == "up" ? current_index - 1 : current_index + 1
      adjacent = contents[target_index] if target_index.between?(0, contents.length - 1)
      swap_content_positions(content, adjacent) if adjacent
    end

    AuditRecorder.record!(
      action: "course.content_reordered",
      auditable: @course,
      metadata: { name: @course.name, content_type: content.contentable_type, content_title: content.contentable.title }
    )
    redirect_to organization_course_path(Current.organization, @course, anchor: "course-content-#{content.id}"), notice: "Course content reordered."
  end

  def move_content_to_section
    authorize @course, :arrange_contents?
    content = @course.course_contents.find(params[:content_id])
    target_section = @course.course_sections.find(params[:course_section_id])

    @course.with_lock do
      source_section = content.course_section
      content.update!(course_section: target_section, position: target_section.course_contents.maximum(:position).to_i + 1)
      resequence_contents(source_section)
    end

    redirect_to organization_course_path(Current.organization, @course, anchor: "course-content-#{content.id}"), notice: "Module moved to #{target_section.name}."
  end

  private
    def set_course
      @course = Current.organization.courses.find(params[:id])
    end

    def course_params
      params.require(:course).permit(:name, :description)
    end

    def load_course_contents
      visible_types = []
      visible_types << "Material" if policy(Material).index?
      visible_types << "Quiz" if policy(Quiz).index?
      @course_contents = @course.course_contents.where(contentable_type: visible_types).includes(:contentable).ordered
      @course_sections = @course.course_sections.includes(course_contents: :contentable).ordered

      materials = @course_contents.filter_map { |content| content.contentable if content.material? }
      quizzes = @course_contents.filter_map { |content| content.contentable if content.quiz? }
      material_associations = [ { cover_image_attachment: :blob }, { blocks: { image_attachment: :blob } } ]
      ActiveRecord::Associations::Preloader.new(records: materials, associations: material_associations).call if materials.any?
      ActiveRecord::Associations::Preloader.new(records: quizzes, associations: :questions).call if quizzes.any?
      @quiz_attempts = Current.membership.quiz_attempts.active.where(quiz: quizzes).order(:attempt_number, :id).index_by(&:quiz_id)
    end

    def swap_content_positions(content, adjacent)
      original_position = content.position
      adjacent_position = adjacent.position
      content.update_columns(position: -content.id)
      adjacent.update_columns(position: original_position)
      content.update_columns(position: adjacent_position)
    end

    def resequence_contents(section)
      section.course_contents.ordered_within_section.each_with_index do |content, index|
        content.update_columns(position: index + 1)
      end
    end

    def enrollment_params
      params.fetch(:course, {}).permit(membership_ids: [])
    end

    def load_students
      @students = eligible_students.includes(:user).joins(:user).order("users.name")
      @enrolled_membership_ids = @course.course_enrollments.pluck(:membership_id)
    end

    def load_course_progress(courses)
      @course_progress = CourseProgress.for(courses: courses, memberships: [ Current.membership ])
    end

    def load_student_progress
      @progress_students = @course.enrolled_memberships
        .joins(user: { role_assignments: :role })
        .where(roles: { organization_id: Current.organization.id, key: "student" })
        .distinct
        .includes(:user)
        .joins(:user)
        .order("users.name")
      @student_progress = CourseProgress.for(courses: [ @course ], memberships: @progress_students)
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
