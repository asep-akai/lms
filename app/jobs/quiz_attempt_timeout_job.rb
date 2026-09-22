class QuizAttemptTimeoutJob < ApplicationJob
  queue_as :background

  def perform(attempt_id)
    QuizAttempt.find_by(id: attempt_id)&.submit_due_to_timeout!
  end
end
