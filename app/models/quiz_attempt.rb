class QuizAttempt < ApplicationRecord
  belongs_to :quiz
  belongs_to :membership
  has_many :answers, class_name: "QuizAnswer", dependent: :destroy, inverse_of: :quiz_attempt
  has_many :answer_overrides, class_name: "QuizAnswerOverride", dependent: :destroy

  validates :membership_id, uniqueness: { scope: :quiz_id }
  validate :membership_is_enrolled

  def submitted? = submitted_at.present?
  def in_progress? = !submitted?
  def reviewed? = reviewed_at.present?
  def waiting_for_review? = submitted? && !reviewed?

  scope :in_progress, -> { where(submitted_at: nil) }
  scope :waiting_for_review, -> { where.not(submitted_at: nil).where(reviewed_at: nil) }
  scope :reviewed, -> { where.not(reviewed_at: nil) }

  def submit!
    submitted_time = Time.current
    update_columns(submitted_at: submitted_time, last_activity_at: submitted_time, updated_at: submitted_time)
  end

  def mark_reviewed!
    update!(reviewed_at: Time.current)
  end

  def mark_unreviewed!
    update!(reviewed_at: nil)
  end

  private
    def membership_is_enrolled
      return unless quiz && membership
      return if quiz.course.course_enrollments.exists?(membership: membership)

      errors.add(:membership, "must be enrolled in this quiz's course")
    end
end
