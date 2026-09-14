class Quiz < ApplicationRecord
  belongs_to :course
  has_many :questions, -> { order(:position, :id) }, class_name: "QuizQuestion", dependent: :destroy, inverse_of: :quiz
  has_many :attempts, class_name: "QuizAttempt", dependent: :destroy

  delegate :organization, to: :course

  validates :title, presence: true, length: { maximum: 160 }
  validates :description, length: { maximum: 5_000 }
end
