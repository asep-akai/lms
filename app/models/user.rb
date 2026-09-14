class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable

  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :role_assignments, as: :assignee, dependent: :destroy
  has_many :roles, through: :role_assignments
  has_many :audit_events, as: :actor, dependent: :nullify

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true, length: { maximum: 120 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :status, inclusion: { in: %w[active suspended] }

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :suspended
  end

  def can?(permission_key, organization:)
    active? && memberships.active.exists?(organization: organization) && role_assignments.joins(role: :permissions)
      .where(roles: { organization_id: organization.id }, permissions: { key: permission_key })
      .exists?
  end

  def organization_admin?(organization)
    active? && memberships.active.exists?(organization: organization) && roles.exists?(organization: organization, key: "admin")
  end
end
