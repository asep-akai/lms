class Organizations::QuizAttemptsController < Organizations::BaseController
  before_action :set_course
  before_action :set_quiz

  def attempt
    authorize @quiz, :show?
    @attempt = find_or_start_attempt
    return redirect_submitted_attempt if @attempt.submitted?

    @questions = @quiz.questions.includes(:answer_options)
    @question = selected_question
    @attempt.update_column(:last_question_position, @question.position)
    @answer = @attempt.answers.find_by(quiz_question: @question) || QuizAnswer.new
    set_attempt_progress
    render :show
  end

  def update_answer
    authorize @quiz, :show?
    attempt = find_or_start_attempt
    return redirect_submitted_attempt if attempt.submitted?

    question = @quiz.questions.find(params[:question_id])
    answer = attempt.answers.find_or_initialize_by(quiz_question: question)
    answer.assign_attributes(answer_params(question))

    if answer_blank?(answer, question)
      answer.destroy! if answer.persisted?
      redirect_after_answer(question, attempt)
      return
    end

    if answer.save
      attempt.update_column(:last_activity_at, Time.current)
      redirect_after_answer(question, attempt)
    else
      @attempt = attempt
      @questions = @quiz.questions.includes(:answer_options)
      @question = question
      @answer = answer
      set_attempt_progress
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_course
      @course = Current.organization.courses.find(params[:course_id])
      authorize @course, :show?
    end

    def set_quiz
      @quiz = @course.quizzes.find(params[:id] || params[:quiz_id])
    end

    def find_or_start_attempt
      QuizAttempt.find_or_create_by!(quiz: @quiz, membership: Current.membership) do |attempt|
        attempt.started_at = Time.current
        attempt.last_activity_at = Time.current
      end
    end

    def answer_params(question)
      answer = params.fetch(:quiz_answer, {}).permit(:quiz_answer_option_id, :short_answer_response)

      if question.multiple_choice?
        { quiz_answer_option_id: answer[:quiz_answer_option_id], short_answer_response: nil }
      else
        { short_answer_response: answer[:short_answer_response], quiz_answer_option_id: nil }
      end
    end

    def selected_question
      requested_position = (params[:question].presence || @attempt.last_question_position).to_i
      @questions.find { |question| question.position == requested_position } || @questions.first
    end

    def answer_blank?(answer, question)
      question.multiple_choice? ? answer.quiz_answer_option_id.blank? : answer.short_answer_response.blank?
    end

    def redirect_after_answer(question, attempt)
      if params[:submit_attempt].present?
        attempt.submit!
        redirect_to organization_course_path(Current.organization, @course), notice: "Quiz submitted. Your attempt is in review."
        return
      end

      if params[:leave_quiz].present?
        redirect_to organization_course_path(Current.organization, @course), notice: "Quiz progress saved."
        return
      end

      target_position = params[:next_question].presence
      if target_position
        redirect_to attempt_organization_course_quiz_path(Current.organization, @course, @quiz, question: target_position)
      else
        redirect_to organization_course_path(Current.organization, @course), notice: "Quiz progress saved."
      end
    end

    def redirect_submitted_attempt
      redirect_to organization_course_path(Current.organization, @course), alert: "This quiz has been submitted and is in review."
    end

    def set_attempt_progress
      @unanswered_questions_count = @questions.size - @attempt.answers.count
      @current_answer_saved = @answer.persisted?
    end
end
