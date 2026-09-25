class Quiz < ApplicationRecord
  belongs_to :course
  has_one :course_content, as: :contentable, dependent: :destroy, inverse_of: :contentable
  has_many :pages, -> { order(:position, :id) }, class_name: "QuizPage", dependent: :destroy, inverse_of: :quiz
  has_many :questions, -> { order(:position, :id) }, class_name: "QuizQuestion", dependent: :destroy, inverse_of: :quiz
  has_many :attempts, class_name: "QuizAttempt", dependent: :destroy
  attr_accessor :course_section_id

  delegate :organization, to: :course

  validates :title, presence: true, length: { maximum: 160 }
  validates :description, length: { maximum: 5_000 }
  validates :retake_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :time_limit_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  after_create :create_default_page
  after_create :append_to_course_contents

  def maximum_attempts = 1 + retake_limit.to_i

  def remaining_retakes_for(membership)
    attempts_used = attempts.where(membership: membership).count
    retakes_used = [ attempts_used - 1, 0 ].max
    [ retake_limit.to_i - retakes_used, 0 ].max
  end

  def time_limited? = time_limit_minutes.present?

  def default_page
    pages.first || pages.create!(title: "Page 1", position: 1)
  end

  def build_next_page(attributes = {})
    next_position = pages.maximum(:position).to_i + 1
    page = pages.build(attributes.merge(position: next_position))
    page.title = "Page #{next_position}" if page.title.blank?
    page
  end

  def resequence_questions_by_page!
    pages.includes(:questions).each_with_object([]) { |page, ordered| ordered.concat(page.questions.to_a) }
      .each_with_index { |question, index| question.update_column(:position, index + 1) }
  end

  private
    def create_default_page
      pages.create!(title: "Page 1", position: 1)
    end

    def append_to_course_contents
      CourseContent.append!(self, course_section: selected_course_section)
    end

    def selected_course_section
      course.course_sections.find_by(id: course_section_id) || course.default_section
    end
end
