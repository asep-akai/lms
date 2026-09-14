class Organizations::AuditEventsController < Organizations::BaseController
  def index
    authorize AuditEvent
    @audit_events = policy_scope(AuditEvent).includes(:actor, :auditable).recent.limit(100)
  end
end
