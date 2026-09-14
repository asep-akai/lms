class QuizAnswerOption < ApplicationRecord
  belongs_to :quiz_question, inverse_of: :answer_options
  has_many :answers, class_name: "QuizAnswer", dependent: :nullify

  validates :content, presence: true, length: { maximum: 2_000 }
end
