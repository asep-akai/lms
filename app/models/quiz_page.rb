class QuizPage < ApplicationRecord
  belongs_to :quiz, inverse_of: :pages
  has_many :questions, -> { order(:position, :id) }, class_name: "QuizQuestion", dependent: :restrict_with_error, inverse_of: :quiz_page
  has_many :blocks, -> { order(:position, :id) }, class_name: "QuizPageBlock", dependent: :destroy, inverse_of: :quiz_page

  accepts_nested_attributes_for :blocks, allow_destroy: true

  validates :title, presence: true, length: { maximum: 160 }
  validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :quiz_id }
end
