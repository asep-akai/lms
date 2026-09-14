class QuizAnswer < ApplicationRecord
  belongs_to :quiz_attempt, inverse_of: :answers
  belongs_to :quiz_question
  belongs_to :quiz_answer_option, optional: true

  validate :answer_matches_question_type

  private
    def answer_matches_question_type
      return unless quiz_question

      if quiz_question.multiple_choice?
        errors.add(:quiz_answer_option, "must be a choice for this question") unless quiz_question.answer_options.exists?(id: quiz_answer_option_id)
      elsif short_answer_response.blank?
        errors.add(:short_answer_response, "cannot be blank")
      end
    end
end
