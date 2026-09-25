class Organizations::EvaluationsController < Organizations::BaseController
  before_action :set_attempt, only: :show

  def index
    authorize :evaluation
    @query = TableSearch.normalize(params[:query])
    attempts = Current.membership.quiz_attempts.active.reviewed.joins(quiz: :course)
    @attempts = TableSearch.call(
      attempts,
      query: @query,
      columns: %w[quizzes.title courses.name]
    )
      .includes(
        :answer_overrides,
        :answer_ai_grades,
        :answer_feedbacks,
        :certificates,
        { quiz: [ :course, { questions: :answer_options } ] },
        { answers: [ :quiz_answer_option, { audio_response_attachment: :blob } ] }
      )
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
      @attempt = QuizAttempt.includes(
        :answer_overrides,
        :answer_ai_grades,
        :answer_feedbacks,
        :certificates,
        membership: :user,
        quiz: { questions: :answer_options },
        answers: [ :quiz_answer_option, { audio_response_attachment: :blob } ]
      ).find(params[:id])
    end

    def set_back_destination
      if params[:from] == "course"
        @back_label = "Back to course"
        @back_path = organization_course_path(Current.organization, @attempt.quiz.course)
      elsif params[:from] == "quiz"
        @back_label = "Back to quiz"
        @back_path = organization_course_quiz_path(Current.organization, @attempt.quiz.course, @attempt.quiz, from: "course")
      elsif params[:from] == "student" && StudentPolicy.new(current_user, @attempt.membership).show?
        @back_label = "Back to student"
        @back_path = organization_student_path(Current.organization, @attempt.membership)
      else
        @back_label = "Back to evaluation"
        @back_path = organization_evaluation_path(Current.organization)
      end
    end
end
