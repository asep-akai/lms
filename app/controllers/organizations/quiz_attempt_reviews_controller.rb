class Organizations::QuizAttemptReviewsController < Organizations::BaseController
  before_action :set_attempt, only: %i[show automatic_grade update_feedback review unreview grade_answer reset_grade reset]
  before_action :reject_cancelled_attempt, only: %i[automatic_grade update_feedback review unreview grade_answer reset_grade reset]

  def index
    authorize QuizAttempt
    @status = params[:status].presence_in(%w[in_progress waiting_for_review waiting_for_confirmation reviewed cancelled])
    @query = TableSearch.normalize(params[:query])
    attempts = policy_scope(QuizAttempt).joins({ membership: :user }, quiz: :course).includes(
      { membership: :user },
      { quiz: [ :course, { questions: :answer_options } ] },
      { answers: :quiz_answer_option },
      :answer_overrides,
      :certificates
    )
    attempts = attempts.public_send(@status) if @status
    attempts = TableSearch.call(
      attempts,
      query: @query,
      columns: %w[quizzes.title courses.name users.name users.email]
    )
    @attempts = attempts.order(Arel.sql("COALESCE(reviewed_at, submitted_at, last_activity_at, started_at) DESC"))
    @gradings_by_attempt_id = @attempts.to_h { |attempt| [ attempt.id, QuizAttemptGrader.new(attempt) ] }
  end

  def show
    authorize @attempt
    @grading = QuizAttemptGrader.new(@attempt)
  end

  def automatic_grade
    authorize @attempt, :ai_analyze?
    return redirect_to organization_grading_path(Current.organization), alert: "Only submitted attempts can be analyzed." unless @attempt.submitted?

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.info("[Automatic grading] Started attempt_id=#{@attempt.id} organization_id=#{Current.organization.id}")
    analysis = QuizAttemptPerformanceAnalyzer.call(@attempt)
    QuizAttempt.transaction do
      @attempt.answer_overrides.destroy_all
      @attempt.update!(
        grading_mode: "ai",
        performance_analysis: analysis.performance_analysis,
        strengths: analysis.strengths,
        weaknesses: analysis.weaknesses,
        recommendations: analysis.recommendations,
        ai_analysis_generated_at: Time.current,
        ai_model: analysis.model,
        ai_response_id: analysis.response_id,
        reviewed_at: nil
      )
    end
    AuditRecorder.record!(
      action: "quiz_attempt.ai_analysis_generated",
      auditable: @attempt,
      metadata: { quiz: @attempt.quiz.title, model: analysis.model }
    )
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    Rails.logger.info("[Automatic grading] Completed attempt_id=#{@attempt.id} model=#{analysis.model} duration_ms=#{duration_ms}")

    redirect_to organization_grading_attempt_path(Current.organization, @attempt), notice: "AI analysis generated. Check the draft before publishing it."
  rescue Ai::Error => error
    duration_ms = started_at && ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    Rails.logger.error("[Automatic grading] Failed attempt_id=#{@attempt.id} error=#{error.class} duration_ms=#{duration_ms} message=#{error.message.inspect}")
    redirect_to organization_grading_attempt_path(Current.organization, @attempt), alert: error.message
  end

  def update_feedback
    authorize @attempt, :review?
    return redirect_to organization_grading_attempt_path(Current.organization, @attempt), alert: "Only submitted attempts can have grading feedback." unless @attempt.submitted?
    return redirect_to organization_grading_attempt_path(Current.organization, @attempt), alert: "Unpublish the results before editing feedback." if @attempt.reviewed?

    @attempt.update!(feedback_params.merge(grading_mode: @attempt.grading_mode || "manual"))
    redirect_to organization_grading_attempt_path(Current.organization, @attempt), notice: "Grading draft saved."
  end

  def review
    authorize @attempt, :review?
    return redirect_to organization_grading_attempt_path(Current.organization, @attempt), alert: "Only submitted attempts can be published." unless @attempt.submitted?

    @attempt.publish!(feedback_params.merge(grading_mode: @attempt.grading_mode || "manual"))
    AuditRecorder.record!(action: "quiz_attempt.results_published", auditable: @attempt, metadata: { quiz: @attempt.quiz.title })
    redirect_to organization_grading_attempt_path(Current.organization, @attempt), notice: "Results published to the student."
  end

  def unreview
    authorize @attempt, :review?
    removed_certificates = @attempt.certificates.count
    QuizAttempt.transaction do
      @attempt.certificates.destroy_all
      @attempt.unpublish!
    end
    AuditRecorder.record!(
      action: "quiz_attempt.results_unpublished",
      auditable: @attempt,
      metadata: { quiz: @attempt.quiz.title, removed_certificates: removed_certificates }
    )
    notice = "Results unpublished."
    notice += " The generated certificate was removed and must be regenerated after publishing." if removed_certificates.positive?
    redirect_to organization_grading_attempt_path(Current.organization, @attempt), notice: notice
  end

  def grade_answer
    authorize @attempt, :review?
    return redirect_to organization_grading_attempt_path(Current.organization, @attempt), alert: "Only submitted attempts can be graded." unless @attempt.submitted?
    return redirect_to organization_grading_attempt_path(Current.organization, @attempt), alert: "Unpublish the results before changing grades." if @attempt.reviewed?

    question = @attempt.quiz.questions.find(params[:question_id])
    answer_override = @attempt.answer_overrides.find_or_initialize_by(quiz_question: question)
    answer_override.update!(correct: ActiveModel::Type::Boolean.new.cast(params.require(:correct)))
    redirect_to organization_grading_attempt_path(Current.organization, @attempt, anchor: "question-#{question.id}"), notice: "Answer grade updated."
  end

  def reset_grade
    authorize @attempt, :review?
    return redirect_to organization_grading_attempt_path(Current.organization, @attempt), alert: "Unpublish the results before changing grades." if @attempt.reviewed?

    question = @attempt.quiz.questions.find(params[:question_id])
    @attempt.answer_overrides.find_by(quiz_question: question)&.destroy!
    redirect_to organization_grading_attempt_path(Current.organization, @attempt, anchor: "question-#{question.id}"), notice: "Automatic grading restored."
  end

  def reset
    authorize @attempt, :reset?
    quiz_title = @attempt.quiz.title
    student_name = @attempt.membership.user.name

    QuizAttempt.transaction do
      AuditRecorder.record!(
        action: "quiz_attempt.reset",
        auditable: @attempt,
        metadata: { quiz: quiz_title, student: student_name }
      )
      @attempt.destroy!
    end

    redirect_to organization_grading_path(Current.organization), notice: "Attempt reset. #{student_name} can retry #{quiz_title}."
  end

  private
    def set_attempt
      @attempt = policy_scope(QuizAttempt).includes(membership: :user, quiz: { questions: :answer_options }, answers: :quiz_answer_option, answer_overrides: [], certificates: []).find(params[:id])
    end

    def feedback_params
      params.fetch(:quiz_attempt, ActionController::Parameters.new).permit(*QuizAttempt::FEEDBACK_FIELDS)
    end

    def reject_cancelled_attempt
      return unless @attempt.cancelled?

      redirect_to organization_grading_attempt_path(Current.organization, @attempt), alert: "Cancelled attempts are retained as read-only audit records."
    end
end
