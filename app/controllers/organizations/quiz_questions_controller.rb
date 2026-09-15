class Organizations::QuizQuestionsController < Organizations::BaseController
  before_action :set_course
  before_action :set_quiz
  before_action :set_question, only: %i[update destroy move]

  def create
    authorize @quiz, :update?
    @question = @quiz.questions.new(question_params.merge(position: next_position))

    if @question.save
      record_question_change("quiz.question_created", 0, 1)
      redirect_to editor_path, notice: "Question added."
    else
      load_editor
      render "organizations/quizzes/edit", status: :unprocessable_entity
    end
  end

  def update
    authorize @quiz, :update?

    if @question.update(question_params)
      record_question_change("quiz.question_updated", 1, 1)
      redirect_to editor_path, notice: "Question updated."
    else
      load_editor
      render "organizations/quizzes/edit", status: :unprocessable_entity
    end
  end

  def destroy
    authorize @quiz, :update?
    @question.destroy!
    record_question_change("quiz.question_deleted", 1, 0)
    redirect_to editor_path, notice: "Question removed."
  end

  def move
    authorize @quiz, :update?
    direction = params[:direction]
    adjacent_question = direction == "up" ? previous_question : next_question

    unless adjacent_question
      redirect_to editor_path, alert: "That question cannot be moved further."
      return
    end

    QuizQuestion.transaction do
      current_position = @question.position
      @question.update!(position: adjacent_question.position)
      adjacent_question.update!(position: current_position)
    end

    AuditRecorder.record!(
      action: "quiz.question_reordered",
      auditable: @quiz,
      metadata: { title: @quiz.title, question_id: @question.id, direction: direction }
    )
    redirect_to editor_path, notice: "Question moved #{direction}."
  end

  private
    def set_course
      @course = Current.organization.courses.find(params[:course_id])
      authorize @course, :show?
    end

    def set_quiz
      @quiz = @course.quizzes.find(params[:quiz_id])
    end

    def set_question
      @question = @quiz.questions.find(params[:id])
    end

    def question_params
      params.require(:quiz_question).permit(
        :question_type,
        :content_html,
        :short_answer,
        answer_options_attributes: [ :id, :content, :correct, :_destroy ]
      )
    end

    def next_position
      @quiz.questions.maximum(:position).to_i + 1
    end

    def previous_question
      @quiz.questions.where("position < ?", @question.position).order(position: :desc).first
    end

    def next_question
      @quiz.questions.where("position > ?", @question.position).order(:position).first
    end

    def load_editor
      @questions = @quiz.questions.includes(:answer_options)
      @new_question = @question.new_record? ? @question : @quiz.questions.new(question_type: :multiple_choice)
    end

    def record_question_change(action, before_count, after_count)
      AuditRecorder.record!(
        action: action,
        auditable: @quiz,
        metadata: { title: @quiz.title },
        changes: { question_count: [ @quiz.questions.count - after_count + before_count, @quiz.questions.count ] }
      )
    end

    def editor_path
      edit_organization_course_quiz_path(Current.organization, @course, @quiz, from: params[:from] == "course" ? "course" : nil)
    end
end
