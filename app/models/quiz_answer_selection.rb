class QuizAnswerSelection < ApplicationRecord
  belongs_to :quiz_answer
  belongs_to :quiz_answer_option

  validates :quiz_answer_option_id, uniqueness: { scope: :quiz_answer_id }
  validate :option_belongs_to_answer_question

  private
    def option_belongs_to_answer_question
      return unless quiz_answer && quiz_answer_option
      return if quiz_answer_option.quiz_question_id == quiz_answer.quiz_question_id

      errors.add(:quiz_answer_option, "must belong to the answered question")
    end
end
