class CourseContent < ApplicationRecord
  CONTENT_TYPES = %w[Material Quiz].freeze

  belongs_to :course
  belongs_to :contentable, polymorphic: true

  validates :contentable_type, inclusion: { in: CONTENT_TYPES }
  validates :contentable_id, uniqueness: { scope: :contentable_type }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :content_belongs_to_course

  scope :ordered, -> { order(:position, :id) }

  def self.append!(contentable)
    contentable.course.with_lock do
      create!(
        course: contentable.course,
        contentable: contentable,
        position: contentable.course.course_contents.maximum(:position).to_i + 1
      )
    end
  end

  def material? = contentable_type == "Material"
  def quiz? = contentable_type == "Quiz"

  private
    def content_belongs_to_course
      return unless contentable&.respond_to?(:course_id)
      return if contentable.course_id == course_id

      errors.add(:contentable, "must belong to the same course")
    end
end
