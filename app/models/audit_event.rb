class AuditEvent < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :actor, polymorphic: true, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc, id: :desc) }

  def readonly?
    persisted?
  end
end
