class QuizAnswerAiTranscription < ApplicationRecord
  belongs_to :quiz_attempt
  belongs_to :quiz_question

  validates :transcript, presence: true, length: { maximum: 100_000 }
  validates :model, presence: true, length: { maximum: 160 }
  validates :quiz_question_id, uniqueness: { scope: :quiz_attempt_id }
  validate :question_belongs_to_attempt_quiz
  validate :question_is_audio

  private
    def question_belongs_to_attempt_quiz
      return unless quiz_attempt && quiz_question
      return if quiz_question.quiz_id == quiz_attempt.quiz_id

      errors.add(:quiz_question, "must belong to the attempted quiz")
    end

    def question_is_audio
      return unless quiz_question
      return if quiz_question.audio?

      errors.add(:quiz_question, "must be an audio question")
    end
end
