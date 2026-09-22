class Organizations::AuditEventsController < Organizations::BaseController
  def index
    authorize AuditEvent
    @query = TableSearch.normalize(params[:query])
    events = TableSearch.call(
      policy_scope(AuditEvent),
      query: @query,
      columns: [ "audit_events.action", "CAST(audit_events.metadata AS text)", "CAST(audit_events.changes AS text)" ]
    )
    @audit_events = events.includes(:actor, :auditable).recent.limit(100)
  end
end
