class AuditRecorder
  def self.record!(action:, auditable: nil, organization: Current.organization, actor: Current.user, metadata: {})
    AuditEvent.create!(
      action: action,
      auditable: auditable,
      organization: organization,
      actor: actor,
      metadata: metadata,
      occurred_at: Time.current
    )
  end
end
