class QuizAnswerFeedback < ApplicationRecord
  ORIGINS = %w[ai reviewer].freeze

  belongs_to :quiz_attempt
  belongs_to :quiz_question

  validates :content, presence: true, length: { maximum: 10_000 }
  validates :origin, inclusion: { in: ORIGINS }
  validates :model, length: { maximum: 160 }, allow_nil: true
  validates :quiz_question_id, uniqueness: { scope: :quiz_attempt_id }
  validate :question_belongs_to_attempt_quiz
  validate :question_is_essay
  validate :ai_feedback_has_model

  def ai_generated? = origin == "ai"

  private
    def question_belongs_to_attempt_quiz
      return unless quiz_attempt && quiz_question
      return if quiz_question.quiz_id == quiz_attempt.quiz_id

      errors.add(:quiz_question, "must belong to the attempted quiz")
    end

    def question_is_essay
      return unless quiz_question
      return if quiz_question.essay?

      errors.add(:quiz_question, "must be an essay question")
    end

    def ai_feedback_has_model
      errors.add(:model, "must be present for AI feedback") if ai_generated? && model.blank?
    end
end
