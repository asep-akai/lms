class Course < ApplicationRecord
  belongs_to :organization
  has_many :course_enrollments, dependent: :destroy
  has_many :enrolled_memberships, through: :course_enrollments, source: :membership
  has_many :quizzes, dependent: :destroy

  validates :name, presence: true, length: { maximum: 160 }
  validates :description, presence: true, length: { maximum: 5_000 }

  scope :ordered, -> { order(:name) }
end
