class Organizations::QuizzesController < Organizations::BaseController
  CONNECTION_CHECK_PAYLOAD = SecureRandom.random_bytes(128.kilobytes).freeze

  before_action :set_course
  before_action :set_quiz, only: %i[show edit update destroy connection_check]

  def index
    authorize Quiz
    @quizzes = policy_scope(@course.quizzes).includes(questions: :answer_options).order(:title)
  end

  def show
    authorize @quiz
    return if policy(@quiz).update?

    @attempt = Current.membership.quiz_attempts.active.where(quiz: @quiz).order(:attempt_number, :id).last
    @attempt&.submit_due_to_timeout!
    @attempt&.reload
    @remaining_retakes = @quiz.remaining_retakes_for(Current.membership)
    load_module_navigation(@quiz) unless @attempt&.in_progress?
  end

  def connection_check
    authorize @quiz, :show?
    expires_now
    if params[:probe] == "download"
      response.headers["Content-Encoding"] = "identity"
      send_data CONNECTION_CHECK_PAYLOAD, type: "application/octet-stream", disposition: "inline"
    else
      head :no_content
    end
  end

  def new
    @quiz = @course.quizzes.new
    @quiz.course_section_id = params[:course_section_id]
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
    @quiz.course_section_id = @quiz.course_content.course_section_id
    load_editor
  end

  def update
    authorize @quiz
    if @quiz.update(quiz_params)
      move_to_selected_section(@quiz)
      AuditRecorder.record!(
        action: "quiz.updated",
        auditable: @quiz,
        metadata: { title: @quiz.title },
        changes: @quiz.saved_changes.slice("title", "description", "retake_limit", "time_limit_minutes")
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
        :description,
        :retake_limit,
        :time_limit_minutes,
        :course_section_id
      )
    end

    def load_editor
      @questions = @quiz.questions.includes(:answer_options)
      @new_question = @quiz.questions.new(question_type: :multiple_choice)
    end

    def navigation_source
      "course" if params[:from] == "course"
    end

    def move_to_selected_section(quiz)
      return if quiz.course_section_id.blank?

      target_section = @course.course_sections.find(quiz.course_section_id)
      return if quiz.course_content.course_section == target_section

      source_section = quiz.course_content.course_section
      quiz.course_content.update!(course_section: target_section, position: target_section.course_contents.maximum(:position).to_i + 1)
      source_section.course_contents.ordered_within_section.each_with_index do |content, index|
        content.update_columns(position: index + 1)
      end
    end
end
