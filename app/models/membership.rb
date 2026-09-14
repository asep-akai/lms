class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  validates :user_id, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: %w[active suspended] }

  scope :active, -> { where(status: "active") }

  def permission?(key)
    active? && user.can?(key, organization: organization)
  end

  def active?
    status == "active"
  end

  def roles
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
