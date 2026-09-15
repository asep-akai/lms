class Organizations::QuizzesController < Organizations::BaseController
  before_action :set_course
  before_action :set_quiz, only: %i[show edit update destroy]

  def index
    authorize Quiz
    @quizzes = policy_scope(@course.quizzes).includes(questions: :answer_options).order(:title)
  end

  def show
    authorize @quiz
    return if policy(@quiz).update?

    @attempt = Current.membership.quiz_attempts.find_by(quiz: @quiz)
    load_module_navigation(@quiz) unless @attempt&.in_progress?
  end

  def new
    @quiz = @course.quizzes.new
    authorize @quiz
  end

  def create
    @quiz = @course.quizzes.new(quiz_params)
    authorize @quiz

    if @quiz.save
      AuditRecorder.record!(
        action: "quiz.created",
        auditable: @quiz,
        metadata: { title: @quiz.title }
      )
      redirect_to organization_course_quiz_path(Current.organization, @course, @quiz, from: navigation_source), notice: "Quiz created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @quiz
    load_editor
  end

  def update
    authorize @quiz
    if @quiz.update(quiz_params)
      AuditRecorder.record!(
        action: "quiz.updated",
        auditable: @quiz,
        metadata: { title: @quiz.title },
        changes: @quiz.saved_changes.slice("title", "description")
      )
      redirect_to organization_course_quiz_path(Current.organization, @course, @quiz, from: navigation_source), notice: "Quiz updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @quiz
    title = @quiz.title
    @quiz.destroy!
    AuditRecorder.record!(action: "quiz.deleted", auditable: @quiz, metadata: { title: title })
    destination = navigation_source == "course" ? organization_course_path(Current.organization, @course) : organization_course_quizzes_path(Current.organization, @course)
    redirect_to destination, notice: "Quiz deleted."
  end

  private
    def set_course
      @course = Current.organization.courses.find(params[:course_id])
      authorize @course, :show?
    end

    def set_quiz
      @quiz = @course.quizzes.find(params[:id])
    end

    def quiz_params
      params.require(:quiz).permit(
        :title,
        :description
      )
    end

    def load_editor
      @questions = @quiz.questions.includes(:answer_options)
      @new_question = @quiz.questions.new(question_type: :multiple_choice)
    end

    def navigation_source
      "course" if params[:from] == "course"
    end
end
