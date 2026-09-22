class CourseSection < ApplicationRecord
  belongs_to :course
  has_many :course_contents, -> { ordered_within_section }, dependent: :restrict_with_error, inverse_of: :course_section

  validates :name, presence: true, length: { maximum: 160 }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :course_id }

  scope :ordered, -> { order(:position, :id) }
end
