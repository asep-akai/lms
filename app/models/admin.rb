class Admin < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_many :role_assignments, as: :assignee, dependent: :destroy
  has_many :roles, through: :role_assignments
  has_many :audit_events, as: :actor, dependent: :nullify
  has_many :support_messages, as: :author, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 120 }
  validates :status, inclusion: { in: %w[active suspended] }

  def active?
    status == "active"
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :suspended
  end

  def can?(permission_key, organization: nil)
    return false unless active?
    return false if Permission::ORGANIZATION_ONLY_KEYS.include?(permission_key)

    role_assignments.joins(role: :permissions)
      .where(roles: { organization_id: organization&.id }, permissions: { key: permission_key })
      .exists?
  end
end
