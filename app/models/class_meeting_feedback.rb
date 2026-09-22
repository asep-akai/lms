class ClassMeetingFeedback < ApplicationRecord
  AUTHOR_ROLES = %w[teacher student].freeze
  TEXT_FIELDS = %i[comment internal_feedback feedback_to_student topics_discussed next_topics].freeze

  belongs_to :class_meeting
  belongs_to :author_membership, class_name: "Membership"

  normalizes(*TEXT_FIELDS, with: ->(value) { value.to_s.strip.presence })

  validates :author_role, inclusion: { in: AUTHOR_ROLES }
  validates :rating, numericality: { only_integer: true, in: 1..5 }
  validates :author_membership_id, uniqueness: { scope: :class_meeting_id }
  validates(*TEXT_FIELDS, length: { maximum: 5_000 }, allow_blank: true)
  validates :internal_feedback, :feedback_to_student, :topics_discussed, :next_topics,
    presence: true,
    if: :teacher_feedback?
  validate :author_is_assigned_to_class
  validate :author_role_matches_assignment
  validate :class_has_started, on: :create

  delegate :organization, to: :class_meeting

  scope :teacher_feedbacks, -> { where(author_role: "teacher") }
  scope :student_feedbacks, -> { where(author_role: "student") }

  def teacher_feedback? = author_role == "teacher"
  def student_feedback? = author_role == "student"

  private
    def author_is_assigned_to_class
      return if class_meeting.blank? || author_membership.blank?
      return if class_meeting.attendee_memberships.include?(author_membership)

      errors.add(:author_membership, "must be assigned to this class")
    end

    def author_role_matches_assignment
      return if class_meeting.blank? || author_membership.blank? || author_role.blank?

      expected_role = class_meeting.feedback_role_for(author_membership)
      errors.add(:author_role, "does not match the class assignment") unless author_role == expected_role
    end

    def class_has_started
      return if class_meeting.blank? || class_meeting.started?

      errors.add(:class_meeting, "must have started before feedback can be submitted")
    end
end
