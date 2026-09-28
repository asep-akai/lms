class Organizations::SupportTicketsController < Organizations::BaseController
  before_action :set_ticket, only: %i[show update reply escalate download_attachment]

  def index
    authorize SupportTicket
    @query = TableSearch.normalize(params[:query])
    tickets = TableSearch.call(
      policy_scope(SupportTicket), query: @query,
      columns: %w[support_tickets.subject support_tickets.category support_tickets.priority support_tickets.status]
    ).includes(reporter_membership: :user).recent
    @pagination, @tickets = paginate(tickets)
  end

  def new
    @ticket = Current.organization.support_tickets.new(reporter_membership: Current.membership)
    authorize @ticket
  end

  def create
    @ticket = Current.organization.support_tickets.new(ticket_params.except(:message))
    @ticket.reporter_membership = Current.membership
    authorize @ticket
    message = @ticket.messages.build(body: ticket_params[:message], author: Current.membership)

    SupportTicket.transaction do
      @ticket.save!
      message.save!
    end
    SupportTicketNotifier.created(@ticket, message)
    AuditRecorder.record!(action: "support_ticket.created", auditable: @ticket, metadata: { subject: @ticket.subject })
    redirect_to organization_support_ticket_path(Current.organization, @ticket), notice: "Support ticket created."
  rescue ActiveRecord::RecordInvalid
    @ticket.validate
    @ticket.errors.add(:message, message.errors.full_messages.to_sentence) if message&.invalid?
    render :new, status: :unprocessable_entity
  end

  def show
    authorize @ticket
    load_messages
  end

  def update
    authorize @ticket
    if @ticket.update(status: params.require(:support_ticket)[:status])
      SupportTicketNotifier.status_changed(@ticket, actor: Current.membership) if @ticket.saved_change_to_status?
      AuditRecorder.record!(action: "support_ticket.status_changed", auditable: @ticket, changes: @ticket.saved_changes.slice("status"))
      redirect_to organization_support_ticket_path(Current.organization, @ticket), notice: "Ticket status updated."
    else
      load_messages
      render :show, status: :unprocessable_entity
    end
  end

  def reply
    authorize @ticket, :reply?
    message = @ticket.messages.create!(message_params.merge(author: Current.membership))
    SupportTicketNotifier.replied(message)
    AuditRecorder.record!(action: "support_ticket.replied", auditable: @ticket, metadata: { message_id: message.id })
    redirect_to organization_support_ticket_path(Current.organization, @ticket), notice: "Reply sent."
  rescue ActiveRecord::RecordInvalid => error
    @message = error.record
    load_messages
    render :show, status: :unprocessable_entity
  end

  def escalate
    authorize @ticket, :escalate?
    @ticket.update!(escalated_at: Time.current, escalated_by_membership: Current.membership, status: "in_progress")
    SupportTicketNotifier.escalated(@ticket, actor: Current.membership)
    AuditRecorder.record!(action: "support_ticket.escalated", auditable: @ticket, metadata: { subject: @ticket.subject })
    redirect_to organization_support_ticket_path(Current.organization, @ticket), notice: "Ticket escalated to the console support team."
  end

  def download_attachment
    authorize @ticket, :show?
    send_support_attachment(scoped_attachment)
  end

  private
    def set_ticket
      @ticket = policy_scope(SupportTicket).find(params[:id])
    end

    def load_messages
      @messages = @ticket.messages.includes(:author).order(:created_at, :id)
    end

    def ticket_params
      params.require(:support_ticket).permit(:subject, :category, :priority, :message)
    end

    def message_params
      params.require(:support_message).permit(:body, attachments: [])
    end

    def scoped_attachment
      ActiveStorage::Attachment
        .where(record_type: "SupportMessage", record_id: @ticket.messages.select(:id), name: "attachments")
        .find(params[:attachment_id])
    end

    def send_support_attachment(attachment)
      response.headers["Cache-Control"] = "private, no-store"
      send_data attachment.download,
        filename: attachment.filename.to_s,
        type: "application/octet-stream",
        disposition: "attachment"
    end
end
