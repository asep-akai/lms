class Organizations::QuizAttemptsController < Organizations::BaseController
  before_action :set_course
  before_action :set_quiz

  def attempt
    authorize @quiz, :show?
    @attempt = params[:attempt_id].present? ? requested_attempt : find_or_start_attempt
    return redirect_reset_attempt if @attempt.nil?
    return redirect_timed_out_attempt if @attempt.submit_due_to_timeout!
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
    attempt = current_attempt
    return redirect_reset_attempt if attempt.nil?
    return redirect_submitted_attempt(attempt) if attempt.submitted?
    if attempt.expired? && !timeout_submission_allowed?(attempt)
      attempt.submit_due_to_timeout!
      return redirect_timed_out_attempt
    end

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
    elsif timeout_submission_allowed?(attempt)
      attempt.submit_due_to_timeout!
      redirect_timed_out_attempt
    else
      @attempt = attempt
      @questions = @quiz.questions.includes(:answer_options)
      @question = question
      @answer = answer
      set_attempt_progress
      render :show, status: :unprocessable_entity
    end
  end

  def retake
    authorize @quiz, :show?
    result = QuizAttemptStarter.call(quiz: @quiz, membership: Current.membership, retake: true)
    AuditRecorder.record!(
      action: "quiz_attempt.cancelled_for_retake",
      auditable: result.previous_attempt,
      metadata: {
        quiz: @quiz.title,
        cancelled_attempt_number: result.previous_attempt.attempt_number,
        replacement_attempt_id: result.attempt.id,
        replacement_attempt_number: result.attempt.attempt_number,
        removed_certificate_count: result.removed_certificate_count
      }
    )
    redirect_to attempt_organization_course_quiz_path(
      Current.organization,
      @course,
      @quiz,
      attempt_id: result.attempt.id
    ), notice: "Retake started. Your previous attempt is no longer active."
  rescue QuizAttemptStarter::RetakeUnavailable => error
    redirect_to organization_course_quiz_path(Current.organization, @course, @quiz, from: "course"), alert: error.message
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
      QuizAttemptStarter.call(quiz: @quiz, membership: Current.membership).attempt
    end

    def requested_attempt
      return unless params[:attempt_id].present?

      Current.membership.quiz_attempts.active.find_by(id: params[:attempt_id], quiz: @quiz)
    end

    def current_attempt
      attempts = Current.membership.quiz_attempts.active.where(quiz: @quiz)
      return attempts.find_by(id: params[:quiz_attempt_id]) if params[:quiz_attempt_id].present?

      attempts.order(:attempt_number, :id).last
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
      if params[:time_expired].present?
        attempt.submit_due_to_timeout!
        redirect_timed_out_attempt
        return
      end

      if params[:submit_attempt].present?
        attempt.submit!
        redirect_to organization_course_quiz_path(Current.organization, @course, @quiz, from: "course"), notice: "Quiz submitted. Your attempt is in review."
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

    def redirect_submitted_attempt(attempt = @attempt)
      message = attempt&.timed_out? ? "The time limit was reached and this attempt was submitted automatically." : "This quiz has already been submitted."
      redirect_to organization_course_quiz_path(Current.organization, @course, @quiz, from: "course"), alert: message
    end

    def redirect_timed_out_attempt
      redirect_to organization_course_quiz_path(Current.organization, @course, @quiz, from: "course"), notice: "Time is up. Your saved answers were submitted automatically."
    end

    def redirect_reset_attempt
      redirect_to organization_course_quiz_path(Current.organization, @course, @quiz, from: "course"), alert: "This attempt was reset. Start a new attempt to continue."
    end

    def set_attempt_progress
      @unanswered_questions_count = @questions.size - @attempt.answers.count
      @current_answer_saved = @answer.persisted?
    end

    def timeout_submission_allowed?(attempt)
      params[:time_expired].present? && attempt.expires_at && attempt.expires_at >= 30.seconds.ago
    end
end
