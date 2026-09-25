class QuizAttemptGrader
  Result = Struct.new(:question, :answer, :correct, :overridden, :ai_grade, keyword_init: true)

  attr_reader :attempt, :results

  def initialize(attempt, use_overrides: true, use_ai_grades: true)
    @attempt = attempt
    answers = attempt.answers.index_by(&:quiz_question_id)
    overrides = use_overrides ? attempt.answer_overrides.index_by(&:quiz_question_id) : {}
    ai_grades = use_ai_grades ? attempt.answer_ai_grades.index_by(&:quiz_question_id) : {}
    @results = attempt.quiz.questions.map do |question|
      answer = answers[question.id]
      override = overrides[question.id]
      ai_grade = ai_grades[question.id]
      Result.new(
        question: question,
        answer: answer,
        correct: resolved_correctness(question, answer, override, ai_grade),
        overridden: override.present?,
        ai_grade: ai_grade
      )
    end
  end

  def scored_results = results.reject { |result| result.correct.nil? }
  def correct_count = scored_results.count(&:correct)
  def total_count = scored_results.size
  def percentage = total_count.zero? ? 0 : ((correct_count.to_f / total_count) * 100).round
  def scored? = total_count.positive?
  def fully_graded? = results.none? { |result| result.correct.nil? && !result.question.manual_grading? }
  def ungraded_count = results.count { |result| result.correct.nil? && !result.question.manual_grading? }
  def optionally_unscored_count = results.count { |result| result.correct.nil? && result.question.manual_grading? }

  private
    def resolved_correctness(question, answer, override, ai_grade)
      return nil unless question.included_in_score?
      return override.correct? if override
      return ai_grade.correct? if question.manual_grading? && ai_grade

      answer_key_match?(question, answer)
    end

    def answer_key_match?(question, answer)
      return nil if question.manual_grading?
      return false unless answer
      return answer.quiz_answer_option&.correct? if question.multiple_choice?
      if question.multiple_choice_set?
        selected_ids = answer.selected_options.ids.sort
        correct_ids = question.answer_options.select(&:correct?).map(&:id).sort
        return selected_ids == correct_ids
      end
      if question.cloze?
        responses = answer.cloze_responses.index_by(&:position)
        return question.cloze_answer_sets.each_with_index.all? do |alternatives, index|
          submitted = normalize(responses[index + 1]&.response_text)
          alternatives.any? { |expected| submitted == normalize(expected) }
        end
      end

      normalize(answer.short_answer_response) == normalize(question.short_answer)
    end

    def normalize(value)
      value.to_s.squish.downcase
    end
end
