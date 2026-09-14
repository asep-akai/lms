class QuizAnswerOverride < ApplicationRecord
  belongs_to :quiz_attempt
  belongs_to :quiz_question

  validates :correct, inclusion: { in: [ true, false ] }
  validates :quiz_question_id, uniqueness: { scope: :quiz_attempt_id }
  validate :question_belongs_to_attempt_quiz

  private
    def question_belongs_to_attempt_quiz
      return unless quiz_attempt && quiz_question
      return if quiz_question.quiz_id == quiz_attempt.quiz_id

      errors.add(:quiz_question, "must belong to the attempted quiz")
    end
end
