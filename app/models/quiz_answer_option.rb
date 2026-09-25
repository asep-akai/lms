class QuizAnswerOption < ApplicationRecord
  belongs_to :quiz_question, inverse_of: :answer_options
  has_many :answers, class_name: "QuizAnswer", dependent: :nullify
  has_many :answer_selections, class_name: "QuizAnswerSelection", dependent: :destroy

  validates :content, presence: true, length: { maximum: 2_000 }
end
