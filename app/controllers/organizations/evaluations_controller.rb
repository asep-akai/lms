class Organizations::EvaluationsController < Organizations::BaseController
  before_action :set_attempt, only: :show

  def index
    authorize :evaluation
    @attempts = Current.membership.quiz_attempts.reviewed
      .includes({ quiz: [ :course, { questions: :answer_options } ] }, { answers: :quiz_answer_option }, :answer_overrides)
      .order(reviewed_at: :desc)
    @gradings_by_attempt_id = @attempts.to_h { |attempt| [ attempt.id, QuizAttemptGrader.new(attempt) ] }
  end

  def show
    authorize @attempt, :result?
    @grading = QuizAttemptGrader.new(@attempt)
    set_back_destination
  end

  private
    def set_attempt
      @attempt = QuizAttempt.includes(membership: :user, quiz: { questions: :answer_options }, answers: :quiz_answer_option, answer_overrides: []).find(params[:id])
    end

    def set_back_destination
      if params[:from] == "course"
        @back_label = "Back to course"
        @back_path = organization_course_path(Current.organization, @attempt.quiz.course)
      else
        @back_label = "Back to evaluation"
        @back_path = organization_evaluation_path(Current.organization)
      end
    end
end
