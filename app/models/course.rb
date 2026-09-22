class Course < ApplicationRecord
  belongs_to :organization
  has_many :course_enrollments, dependent: :destroy
  has_many :enrolled_memberships, through: :course_enrollments, source: :membership
  has_many :course_contents, -> { ordered }, dependent: :destroy, inverse_of: :course
  has_many :course_sections, -> { ordered }, dependent: :destroy
  has_many :quizzes, dependent: :destroy
  has_many :materials, dependent: :destroy

  validates :name, presence: true, length: { maximum: 160 }
  validates :description, presence: true, length: { maximum: 5_000 }
  after_create :create_default_section

  scope :ordered, -> { order(:name) }

  def default_section
    course_sections.ordered.first || course_sections.create!(name: "Course content", position: 1)
  end

  private
    def create_default_section
      course_sections.create!(name: "Course content", position: 1)
    end
end
