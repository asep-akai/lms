class Organizations::StudentsController < Organizations::BaseController
  before_action :set_student, only: :show

  def index
    authorize :student, :index?
    @students = student_memberships.includes(:user, :course_enrollments).joins(:user).order("users.name")
  end

  def show
    authorize @student, policy_class: StudentPolicy
    @courses = @student.enrolled_courses.includes(course_contents: :contentable).ordered
    @course_progress = CourseProgress.for(courses: @courses, memberships: [ @student ])
  end

  private
    def set_student
      @student = Current.organization.memberships.find(params[:id])
    end

    def student_memberships
      Current.organization.memberships
        .joins(user: { role_assignments: :role })
        .where(roles: { organization_id: Current.organization.id, key: "student" })
        .distinct
    end
end
