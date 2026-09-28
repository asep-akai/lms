require "uri"

class ClassMeeting < ApplicationRecord
  DELIVERY_MODES = %w[onsite online].freeze

  belongs_to :organization
  belongs_to :teacher_membership, class_name: "Membership"
  belongs_to :cancelled_by_membership, class_name: "Membership", optional: true
  has_many :class_meeting_students, dependent: :destroy
  has_many :student_memberships, through: :class_meeting_students, source: :membership
  has_many :feedbacks, class_name: "ClassMeetingFeedback", dependent: :destroy

  normalizes :subject, with: ->(subject) { subject.to_s.squish }
  normalizes :topic, with: ->(topic) { topic.to_s.squish }
  normalizes :meeting_url, with: ->(meeting_url) { meeting_url.to_s.strip.presence }

  before_validation :set_subject_key
  before_validation :clear_meeting_url_for_onsite_class
  before_validation :assign_meeting_number, if: :sequence_required?

  validates :subject, presence: true, length: { maximum: 160 }
  validates :subject_key, presence: true
  validates :topic, presence: true, length: { maximum: 240 }
  validates :starts_at, presence: true
  validates :delivery_mode, inclusion: { in: DELIVERY_MODES }
  validates :meeting_url, presence: true, if: :online?
  validates :meeting_url, length: { maximum: 2_048 }, allow_blank: true
  validates :meeting_number, numericality: { only_integer: true, greater_than: 0 }
  validates :meeting_number, uniqueness: { scope: %i[organization_id subject_key] }
  validate :teacher_is_eligible
  validate :students_are_eligible
  validate :at_least_one_student
  validate :meeting_url_is_safe

  scope :chronological, -> { order(starts_at: :asc, meeting_number: :asc) }
  scope :scheduled, -> { where(cancelled_at: nil) }
  scope :upcoming, -> { where(starts_at: Time.current..) }
  scope :past, -> { where(starts_at: ...Time.current) }
  scope :reverse_chronological, -> { order(starts_at: :desc, meeting_number: :desc) }

  scope :assigned_to, ->(membership) {
    left_outer_joins(:class_meeting_students)
      .where(
        "class_meetings.teacher_membership_id = :membership_id OR class_meeting_students.membership_id = :membership_id",
        membership_id: membership.id
      )
      .distinct
  }

  def attendee_memberships
    [ teacher_membership, *student_memberships ].compact.uniq
  end

  def onsite? = delivery_mode == "onsite"
  def online? = delivery_mode == "online"
  def started? = starts_at.present? && starts_at <= Time.current
  def cancelled? = cancelled_at.present?

  def reschedule_requestable_by?(membership, now: Time.current)
    !cancelled? &&
      membership&.student? &&
      membership.id.in?(student_membership_ids) &&
      student_memberships.size == 1 &&
      membership.reschedule_quota.positive? &&
      now <= starts_at - 24.hours
  end

  def feedback_role_for(membership)
    return "teacher" if teacher_membership_id == membership&.id

    "student" if membership && student_memberships.exists?(membership.id)
  end

  def safe_meeting_url
    return if meeting_url.blank?

    uri = URI.parse(meeting_url)
    uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    nil
  end

  private
    def set_subject_key
      self.subject_key = subject.to_s.squish.downcase
    end

    def clear_meeting_url_for_onsite_class
      self.meeting_url = nil if onsite?
    end

    def meeting_url_is_safe
      return if meeting_url.blank?

      uri = URI.parse(meeting_url)
      return if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?

      errors.add(:meeting_url, "must be a valid HTTP or HTTPS link")
    rescue URI::InvalidURIError
      errors.add(:meeting_url, "must be a valid HTTP or HTTPS link")
    end

    def sequence_required?
      new_record? || will_save_change_to_subject_key?
    end

    def assign_meeting_number
      return if organization.blank? || subject_key.blank?

      self.meeting_number = organization.class_meetings
        .where(subject_key: subject_key)
        .where.not(id: id)
        .maximum(:meeting_number).to_i + 1
    end

    def teacher_is_eligible
      return if teacher_membership.blank?

      unless teacher_membership.organization_id == organization_id
        errors.add(:teacher_membership, "must belong to this organization")
      end
      errors.add(:teacher_membership, "must be active") unless teacher_membership.active?
      errors.add(:teacher_membership, "must have the Teacher role") unless teacher_membership.roles.exists?(key: "teacher")
    end

    def students_are_eligible
      student_memberships.each do |membership|
        errors.add(:student_memberships, "must belong to this organization") unless membership.organization_id == organization_id
        errors.add(:student_memberships, "must all be active") unless membership.active?
        errors.add(:student_memberships, "must all have the Student role") unless membership.student?
      end
    end

    def at_least_one_student
      errors.add(:student_memberships, "must include at least one student") if student_memberships.empty?
    end
end
