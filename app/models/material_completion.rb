class MaterialCompletion < ApplicationRecord
  belongs_to :material
  belongs_to :membership

  validates :membership_id, uniqueness: { scope: :material_id }
  validate :membership_is_enrolled

  private
    def membership_is_enrolled
      return unless material && membership
      return if material.course.course_enrollments.exists?(membership: membership)

      errors.add(:membership, "must be enrolled in this material's course")
    end
end
