class RoleAssignment < ApplicationRecord
  belongs_to :role
  belongs_to :assignee, polymorphic: true

  validates :role_id, uniqueness: { scope: %i[assignee_type assignee_id] }
  validate :scope_matches_assignee

  private
    def scope_matches_assignee
      return if role.nil? || assignee.nil?
      return if assignee.is_a?(Admin) && role.global?
      return if assignee.is_a?(User) && role.organization.present? && assignee.memberships.exists?(organization: role.organization)

      errors.add(:role, "scope does not match the assignee")
    end
end
