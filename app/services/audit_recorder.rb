class AuditRecorder
  SENSITIVE_FIELDS = %w[encrypted_password password password_confirmation reset_password_token].freeze

  def self.record!(action:, auditable: nil, organization: Current.organization, actor: Current.user, metadata: {}, changes: {})
    payload = metadata.to_h.deep_stringify_keys
    payload.except!(*SENSITIVE_FIELDS)
    normalized_changes = normalize_changes(changes)
    payload["changes"] = normalized_changes if normalized_changes.any?
    payload["actor"] ||= snapshot(actor) if actor
    payload["subject"] ||= snapshot(auditable) if auditable

    AuditEvent.create!(
      action: action,
      auditable: auditable,
      organization: organization,
      actor: actor,
      metadata: payload,
      occurred_at: Time.current
    )
  end

  def self.snapshot(record)
    person = record.is_a?(Membership) ? record.user : record

    {
      type: record.class.name,
      id: record.id,
      name: person.respond_to?(:name) ? person.name : nil,
      email: person.respond_to?(:email) ? person.email : nil
    }.compact
  end

  def self.normalize_changes(changes)
    changes.to_h.each_with_object({}) do |(field, values), normalized|
      next if field.to_s.in?(SENSITIVE_FIELDS)

      before, after = Array(values)
      next if before == after

      normalized[field.to_s] = { "before" => before, "after" => after }
    end
  end

  private_class_method :normalize_changes, :snapshot
end
