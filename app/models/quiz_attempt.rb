class QuizAttempt < ApplicationRecord
  GRADING_MODES = %w[manual ai].freeze
  FEEDBACK_FIELDS = %i[performance_analysis strengths weaknesses recommendations].freeze
  CANCELLATION_REASONS = %w[retake].freeze

  belongs_to :quiz
  belongs_to :membership
  belongs_to :superseded_by_attempt, class_name: "QuizAttempt", optional: true
  has_one :superseded_attempt, class_name: "QuizAttempt", foreign_key: :superseded_by_attempt_id, dependent: :nullify, inverse_of: :superseded_by_attempt
  has_many :answers, class_name: "QuizAnswer", dependent: :destroy, inverse_of: :quiz_attempt
  has_many :answer_overrides, class_name: "QuizAnswerOverride", dependent: :destroy
  has_many :answer_ai_grades, class_name: "QuizAnswerAiGrade", dependent: :destroy
  has_many :answer_ai_transcriptions, class_name: "QuizAnswerAiTranscription", dependent: :destroy
  has_many :answer_feedbacks, class_name: "QuizAnswerFeedback", dependent: :destroy
  has_many :certificates, as: :source, dependent: :destroy

  validates :membership_id, uniqueness: { scope: :quiz_id, conditions: -> { where(cancelled_at: nil) } }, unless: :cancelled?
  validates :attempt_number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: %i[quiz_id membership_id] }
  validates :cancelled_reason, inclusion: { in: CANCELLATION_REASONS }, allow_nil: true
  validates :grading_mode, inclusion: { in: GRADING_MODES }, allow_nil: true
  validates(*FEEDBACK_FIELDS, length: { maximum: 10_000 })
  validate :membership_is_enrolled

  after_create_commit :schedule_timeout

  scope :active, -> { where(cancelled_at: nil) }
  scope :cancelled, -> { where.not(cancelled_at: nil) }
  scope :in_progress, -> { active.where(submitted_at: nil) }
  scope :waiting_for_review, -> { active.where.not(submitted_at: nil).where(reviewed_at: nil, ai_analysis_generated_at: nil) }
  scope :waiting_for_confirmation, -> { active.where.not(submitted_at: nil).where.not(ai_analysis_generated_at: nil).where(reviewed_at: nil) }
  scope :reviewed, -> { active.where.not(reviewed_at: nil) }

  def submitted? = submitted_at.present?
  def cancelled? = cancelled_at.present?
  def active? = !cancelled?
  def in_progress? = active? && !submitted?
  def reviewed? = active? && reviewed_at.present?
  def waiting_for_confirmation? = active? && submitted? && !reviewed? && ai_analysis_generated_at.present?
  def waiting_for_review? = active? && submitted? && !reviewed? && !waiting_for_confirmation?
  def ai_graded? = grading_mode == "ai"
  def timed_out? = timed_out_at.present?
  def expired?(at: Time.current) = expires_at.present? && expires_at <= at
  def result_certificate = active? ? certificates.published.find_by(certificate_type: "exam_result") : nil

  def submit!(timed_out: false)
    submitted_time = Time.current
    with_lock do
      return false if submitted? || cancelled?

      attributes = { submitted_at: submitted_time, last_activity_at: submitted_time, updated_at: submitted_time }
      attributes[:timed_out_at] = submitted_time if timed_out
      update_columns(attributes)
    end
    true
  end

  def submit_due_to_timeout!
    submitted = with_lock do
      next false if submitted? || cancelled? || !expired?

      submitted_time = Time.current
      update_columns(
        submitted_at: submitted_time,
        timed_out_at: submitted_time,
        last_activity_at: submitted_time,
        updated_at: submitted_time
      )
      true
    end
    return false unless submitted

    AuditRecorder.record!(
      action: "quiz_attempt.timed_out",
      auditable: self,
      organization: quiz.course.organization,
      actor: nil,
      metadata: { quiz: quiz.title, student: membership.user.name, attempt_number: attempt_number }
    )
    true
  end

  def publish!(feedback = {})
    update!(feedback.merge(reviewed_at: Time.current))
  end

  def unpublish!
    update!(reviewed_at: nil)
  end

  private
    def schedule_timeout
      return unless expires_at

      QuizAttemptTimeoutJob.set(wait_until: expires_at).perform_later(id)
    end

    def membership_is_enrolled
      return unless quiz && membership
      return if quiz.course.course_enrollments.exists?(membership: membership)

      errors.add(:membership, "must be enrolled in this quiz's course")
    end
end
