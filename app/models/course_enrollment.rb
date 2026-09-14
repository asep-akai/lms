class CourseEnrollment < ApplicationRecord
  belongs_to :course
  belongs_to :membership

  validates :membership_id, uniqueness: { scope: :course_id }
  validate :membership_belongs_to_course_organization
  validate :membership_has_student_role

  private
    def membership_belongs_to_course_organization
      return if course.blank? || membership.blank? || course.organization_id == membership.organization_id

      errors.add(:membership, "must belong to the course organization")
    end

    def membership_has_student_role
      return if membership.blank? || membership.roles.exists?(key: "student")

      errors.add(:membership, "must have the Student role")
    end
end
