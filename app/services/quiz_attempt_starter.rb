class QuizAttemptStarter
  Result = Data.define(:attempt, :previous_attempt, :removed_certificate_count)
  class RetakeUnavailable < StandardError; end

  def self.call(quiz:, membership:, retake: false)
    new(quiz: quiz, membership: membership, retake: retake).call
  end

  def initialize(quiz:, membership:, retake:)
    @quiz = quiz
    @membership = membership
    @retake = retake
  end

  def call
    quiz.with_lock do
      current_attempt = attempts.active.order(:attempt_number, :id).last
      current_attempt&.submit_due_to_timeout!

      return start_retake!(current_attempt) if @retake
      return Result.new(attempt: current_attempt, previous_attempt: nil, removed_certificate_count: 0) if current_attempt

      Result.new(attempt: create_attempt!, previous_attempt: nil, removed_certificate_count: 0)
    end
  end

  private
    attr_reader :quiz, :membership

    def attempts
      quiz.attempts.where(membership: membership)
    end

    def start_retake!(current_attempt)
      raise RetakeUnavailable, "There is no completed attempt to retake." unless current_attempt&.submitted?
      if quiz.remaining_retakes_for(membership).zero?
        raise RetakeUnavailable, "You have used every retake available for this quiz."
      end

      removed_certificate_count = current_attempt.certificates.count
      current_attempt.certificates.destroy_all
      current_attempt.update!(cancelled_at: Time.current, cancelled_reason: "retake")
      replacement = create_attempt!
      current_attempt.update!(superseded_by_attempt: replacement)

      Result.new(
        attempt: replacement,
        previous_attempt: current_attempt,
        removed_certificate_count: removed_certificate_count
      )
    end

    def create_attempt!
      started_at = Time.current
      attempts.create!(
        attempt_number: attempts.maximum(:attempt_number).to_i + 1,
        started_at: started_at,
        last_activity_at: started_at,
        expires_at: quiz.time_limited? ? started_at + quiz.time_limit_minutes.minutes : nil
      )
    end
end
