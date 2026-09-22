class Quiz < ApplicationRecord
  belongs_to :course
  has_one :course_content, as: :contentable, dependent: :destroy, inverse_of: :contentable
  has_many :questions, -> { order(:position, :id) }, class_name: "QuizQuestion", dependent: :destroy, inverse_of: :quiz
  has_many :attempts, class_name: "QuizAttempt", dependent: :destroy
  attr_accessor :course_section_id

  delegate :organization, to: :course

  validates :title, presence: true, length: { maximum: 160 }
  validates :description, length: { maximum: 5_000 }
  validates :retake_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :time_limit_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  after_create :append_to_course_contents

  def maximum_attempts = 1 + retake_limit.to_i

  def remaining_retakes_for(membership)
    attempts_used = attempts.where(membership: membership).count
    retakes_used = [ attempts_used - 1, 0 ].max
    [ retake_limit.to_i - retakes_used, 0 ].max
  end

  def time_limited? = time_limit_minutes.present?

  private
    def append_to_course_contents
      CourseContent.append!(self, course_section: selected_course_section)
    end

    def selected_course_section
      course.course_sections.find_by(id: course_section_id) || course.default_section
    end
end
