class Quiz < ApplicationRecord
  belongs_to :course
  has_one :course_content, as: :contentable, dependent: :destroy, inverse_of: :contentable
  has_many :questions, -> { order(:position, :id) }, class_name: "QuizQuestion", dependent: :destroy, inverse_of: :quiz
  has_many :attempts, class_name: "QuizAttempt", dependent: :destroy

  delegate :organization, to: :course

  validates :title, presence: true, length: { maximum: 160 }
  validates :description, length: { maximum: 5_000 }
  after_create :append_to_course_contents

  private
    def append_to_course_contents
      CourseContent.append!(self)
    end
end
