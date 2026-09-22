class CourseContent < ApplicationRecord
  CONTENT_TYPES = %w[Material Quiz].freeze

  belongs_to :course
  belongs_to :course_section, inverse_of: :course_contents
  belongs_to :contentable, polymorphic: true

  validates :contentable_type, inclusion: { in: CONTENT_TYPES }
  validates :contentable_id, uniqueness: { scope: :contentable_type }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :content_belongs_to_course
  validate :section_belongs_to_course

  scope :ordered_within_section, -> { order(:position, :id) }
  scope :ordered, -> { joins(:course_section).order("course_sections.position", "course_contents.position", "course_contents.id") }

  def self.append!(contentable, course_section: nil)
    contentable.course.with_lock do
      course_section ||= contentable.course.default_section
      create!(
        course: contentable.course,
        course_section: course_section,
        contentable: contentable,
        position: course_section.course_contents.maximum(:position).to_i + 1
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

    def section_belongs_to_course
      return unless course_section && course
      return if course_section.course_id == course_id

      errors.add(:course_section, "must belong to the same course")
    end
end
