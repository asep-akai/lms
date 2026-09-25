class Organization < ApplicationRecord
  TIME_ZONE = "Jakarta".freeze

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :roles, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :class_meetings, dependent: :destroy
  has_many :certificates, dependent: :destroy
  has_many :assignments, dependent: :destroy
  has_many :class_meeting_feedbacks, through: :class_meetings, source: :feedbacks
  has_many :audit_events, dependent: :destroy
  has_many :support_tickets, dependent: :destroy

  normalizes :slug, with: ->(slug) { slug.to_s.strip.downcase.parameterize }

  validates :name, presence: true, length: { maximum: 160 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :status, inclusion: { in: %w[active suspended] }
  validates :timezone, inclusion: { in: [ TIME_ZONE ] }
  validates :locale, presence: true

  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def to_param
    slug
  end
end
