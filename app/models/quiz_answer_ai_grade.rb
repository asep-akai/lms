class QuizAnswerAiGrade < ApplicationRecord
  belongs_to :quiz_attempt
  belongs_to :quiz_question

  validates :correct, inclusion: { in: [ true, false ] }
  validates :rationale, presence: true, length: { maximum: 5_000 }
  validates :model, presence: true, length: { maximum: 160 }
  validates :quiz_question_id, uniqueness: { scope: :quiz_attempt_id }
  validate :question_belongs_to_attempt_quiz
  validate :question_supports_ai_scoring

  private
    def question_belongs_to_attempt_quiz
      return unless quiz_attempt && quiz_question
      return if quiz_question.quiz_id == quiz_attempt.quiz_id

      errors.add(:quiz_question, "must belong to the attempted quiz")
    end

    def question_supports_ai_scoring
      return unless quiz_question
      return if quiz_question.manual_grading? && quiz_question.included_in_score?

      errors.add(:quiz_question, "must be a scored essay or audio question")
    end
end
