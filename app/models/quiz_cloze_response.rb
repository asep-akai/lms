class QuizClozeResponse < ApplicationRecord
  belongs_to :quiz_answer

  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :quiz_answer_id }
  validates :response_text, presence: true, length: { maximum: 1_000 }
  validate :position_exists_in_question

  private
    def position_exists_in_question
      return unless quiz_answer&.quiz_question
      return if position.to_i.between?(1, quiz_answer.quiz_question.cloze_answers.size)

      errors.add(:position, "must identify a blank in the question")
    end
end
