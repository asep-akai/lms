class ClassMeetingStudent < ApplicationRecord
  belongs_to :class_meeting
  belongs_to :membership

  validates :membership_id, uniqueness: { scope: :class_meeting_id }
  validate :membership_is_eligible

  private
    def membership_is_eligible
      return if class_meeting.blank? || membership.blank?

      unless membership.organization_id == class_meeting.organization_id
        errors.add(:membership, "must belong to the class meeting organization")
      end
      errors.add(:membership, "must be active") unless membership.active?
      errors.add(:membership, "must have the Student role") unless membership.student?
    end
end
