class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  has_many :quiz_attempts, dependent: :destroy
  has_many :material_completions, dependent: :destroy
  has_many :course_enrollments, dependent: :destroy
  has_many :teaching_class_meetings, class_name: "ClassMeeting", foreign_key: :teacher_membership_id, dependent: :restrict_with_error, inverse_of: :teacher_membership
  has_many :class_meeting_students, dependent: :destroy
  has_many :attending_class_meetings, through: :class_meeting_students, source: :class_meeting
  has_many :class_meeting_feedbacks, foreign_key: :author_membership_id, dependent: :destroy, inverse_of: :author_membership
  has_many :received_certificates, class_name: "Certificate", foreign_key: :recipient_membership_id, dependent: :destroy, inverse_of: :recipient_membership
  has_many :issued_certificates, class_name: "Certificate", foreign_key: :issued_by_membership_id, dependent: :nullify, inverse_of: :issued_by_membership
  has_many :unpublished_certificates, class_name: "Certificate", foreign_key: :unpublished_by_membership_id, dependent: :nullify, inverse_of: :unpublished_by_membership
  has_many :teaching_assignments, class_name: "Assignment", foreign_key: :teacher_membership_id, dependent: :restrict_with_error, inverse_of: :teacher_membership
  has_many :assignment_recipients, foreign_key: :student_membership_id, dependent: :destroy, inverse_of: :student_membership
  has_many :assigned_assignments, through: :assignment_recipients, source: :assignment
  has_many :reported_support_tickets, class_name: "SupportTicket", foreign_key: :reporter_membership_id, dependent: :restrict_with_error
  has_many :first_participant_direct_conversations, class_name: "DirectConversation", foreign_key: :participant_one_membership_id, dependent: :destroy
  has_many :second_participant_direct_conversations, class_name: "DirectConversation", foreign_key: :participant_two_membership_id, dependent: :destroy
  has_many :sent_direct_messages, class_name: "DirectMessage", foreign_key: :sender_membership_id, dependent: :destroy
  has_many :notifications, foreign_key: :recipient_membership_id, dependent: :destroy, inverse_of: :recipient_membership
  has_many :created_notifications, class_name: "Notification", foreign_key: :actor_membership_id, dependent: :nullify, inverse_of: :actor_membership
  has_many :enrolled_courses, through: :course_enrollments, source: :course
  validates :user_id, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: %w[active suspended] }
  validates :reschedule_quota, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(status: "active") }
  scope :taught_by, ->(teacher_membership) {
    joins(class_meeting_students: :class_meeting)
      .where(class_meetings: {
        organization_id: teacher_membership.organization_id,
        teacher_membership_id: teacher_membership.id
      })
      .distinct
  }

  def permission?(key)
    active? && user.can?(key, organization: organization)
  end

  def active?
    status == "active"
  end

  def organization_admin?
    roles.exists?(key: "admin")
  end

  def student?
    roles.exists?(key: "student")
  end

  def teacher?
    roles.exists?(key: "teacher")
  end

  def notification_recipient?
    student? || teacher?
  end

  def roles
    return Role.none unless user && organization

    user.roles.where(organization: organization)
  end

  def role_ids
    roles.ids
  end

  def role_ids=(ids)
    selected_roles = organization.roles.where(id: Array(ids).reject(&:blank?))
    user.role_assignments.joins(:role).where(roles: { organization_id: organization_id }).where.not(role: selected_roles).destroy_all
    selected_roles.each { |role| user.role_assignments.find_or_create_by!(role: role) }
  end
end
