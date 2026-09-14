class Organization < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :roles, dependent: :destroy
  has_many :audit_events, dependent: :destroy

  normalizes :slug, with: ->(slug) { slug.to_s.strip.downcase.parameterize }

  validates :name, presence: true, length: { maximum: 160 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :status, inclusion: { in: %w[active suspended] }
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
  validates :locale, presence: true

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def to_param
    slug
  end
end
