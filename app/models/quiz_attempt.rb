class QuizAttempt < ApplicationRecord
  belongs_to :quiz
  belongs_to :membership
  has_many :answers, class_name: "QuizAnswer", dependent: :destroy, inverse_of: :quiz_attempt

  validates :membership_id, uniqueness: { scope: :quiz_id }
  validate :membership_is_enrolled

  private
    def membership_is_enrolled
      return unless quiz && membership
      return if quiz.course.course_enrollments.exists?(membership: membership)

      errors.add(:membership, "must be enrolled in this quiz's course")
    end
end
