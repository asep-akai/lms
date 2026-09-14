class QuizAttemptGrader
  Result = Struct.new(:question, :answer, :correct, :overridden, keyword_init: true)

  attr_reader :attempt, :results

  def initialize(attempt)
    @attempt = attempt
    answers = attempt.answers.index_by(&:quiz_question_id)
    overrides = attempt.answer_overrides.index_by(&:quiz_question_id)
    @results = attempt.quiz.questions.map do |question|
      answer = answers[question.id]
      override = overrides[question.id]
      Result.new(
        question: question,
        answer: answer,
        correct: override ? override.correct? : answer_key_match?(question, answer),
        overridden: override.present?
      )
    end
  end

  def correct_count = results.count(&:correct)
  def total_count = results.size
  def percentage = total_count.zero? ? 0 : ((correct_count.to_f / total_count) * 100).round

  private
    def answer_key_match?(question, answer)
      return false unless answer
      return answer.quiz_answer_option&.correct? if question.multiple_choice?

      normalize(answer.short_answer_response) == normalize(question.short_answer)
    end

    def normalize(value)
      value.to_s.squish.downcase
    end
end
