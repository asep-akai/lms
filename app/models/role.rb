class Role < ApplicationRecord
  belongs_to :organization, optional: true
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  has_many :role_assignments, dependent: :restrict_with_error

  normalizes :key, with: ->(key) { key.to_s.strip.downcase.parameterize(separator: "_") }

  validates :name, presence: true, length: { maximum: 80 }
  validates :key, presence: true, uniqueness: { scope: :organization_id }, format: { with: /\A[a-z0-9]+(?:_[a-z0-9]+)*\z/ }

  scope :ordered, -> { order(system: :desc, name: :asc) }

  def editable?
    !system?
  end

  def global?
    organization_id.nil?
  end

  def memberships
    return Membership.none if global?

    organization.memberships.joins(user: :role_assignments).where(role_assignments: { role_id: id }).distinct
  end
end
