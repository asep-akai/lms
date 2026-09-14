class Organizations::QuizAttemptReviewsController < Organizations::BaseController
  before_action :set_attempt, only: %i[show review unreview grade_answer reset_grade reset]

  def index
    authorize QuizAttempt
    @status = params[:status].presence_in(%w[in_progress waiting_for_review reviewed])
    attempts = policy_scope(QuizAttempt).includes(
      { membership: :user },
      { quiz: [ :course, { questions: :answer_options } ] },
      { answers: :quiz_answer_option },
      :answer_overrides
    )
    attempts = attempts.public_send(@status) if @status
    @attempts = attempts.order(Arel.sql("COALESCE(reviewed_at, submitted_at, last_activity_at, started_at) DESC"))
    @gradings_by_attempt_id = @attempts.to_h { |attempt| [ attempt.id, QuizAttemptGrader.new(attempt) ] }
  end

  def show
    authorize @attempt
    @grading = QuizAttemptGrader.new(@attempt)
  end

  def review
    authorize @attempt, :review?
    @attempt.mark_reviewed!
    redirect_to organization_grading_attempt_path(Current.organization, @attempt), notice: "Attempt marked as reviewed."
  end

  def unreview
    authorize @attempt, :review?
    @attempt.mark_unreviewed!
    redirect_to organization_grading_attempt_path(Current.organization, @attempt), notice: "Attempt returned to the review queue."
  end

  def grade_answer
    authorize @attempt, :review?
    return redirect_to organization_grading_attempt_path(Current.organization, @attempt), alert: "Only submitted attempts can be graded." unless @attempt.submitted?

    question = @attempt.quiz.questions.find(params[:question_id])
    answer_override = @attempt.answer_overrides.find_or_initialize_by(quiz_question: question)
    answer_override.update!(correct: ActiveModel::Type::Boolean.new.cast(params.require(:correct)))
    redirect_to organization_grading_attempt_path(Current.organization, @attempt, anchor: "question-#{question.id}"), notice: "Answer grade updated."
  end

  def reset_grade
    authorize @attempt, :review?
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
      @attempt = policy_scope(QuizAttempt).includes(membership: :user, quiz: { questions: :answer_options }, answers: :quiz_answer_option, answer_overrides: []).find(params[:id])
    end
end
