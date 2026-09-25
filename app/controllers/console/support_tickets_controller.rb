module Console
  class SupportTicketsController < BaseController
    before_action :set_ticket, only: %i[show update reply download_attachment]

    def index
      authorize SupportTicket
      @query = TableSearch.normalize(params[:query])
      @tickets = TableSearch.call(
        policy_scope(SupportTicket), query: @query,
        columns: %w[support_tickets.subject support_tickets.category support_tickets.priority support_tickets.status organizations.name]
      ).joins(:organization).includes(:organization, reporter_membership: :user).recent
    end

    def show
      authorize @ticket
      @messages = @ticket.messages.includes(:author).order(:created_at, :id)
    end

    def update
      authorize @ticket
      if @ticket.update(status: params.require(:support_ticket)[:status])
        SupportTicketNotifier.status_changed(@ticket, actor: current_admin) if @ticket.saved_change_to_status?
        AuditRecorder.record!(action: "console.support_ticket.status_changed", auditable: @ticket, organization: @ticket.organization, changes: @ticket.saved_changes.slice("status"))
        redirect_to console_support_ticket_path(@ticket), notice: "Ticket status updated."
      else
        @messages = @ticket.messages.includes(:author).order(:created_at, :id)
        render :show, status: :unprocessable_entity
      end
    end

    def reply
      authorize @ticket, :reply?
      message = @ticket.messages.create!(message_params.merge(author: current_admin))
      SupportTicketNotifier.replied(message)
      AuditRecorder.record!(action: "console.support_ticket.replied", auditable: @ticket, organization: @ticket.organization, metadata: { message_id: message.id })
      redirect_to console_support_ticket_path(@ticket), notice: "Reply sent."
    rescue ActiveRecord::RecordInvalid => error
      @message = error.record
      @messages = @ticket.messages.includes(:author).order(:created_at, :id)
      render :show, status: :unprocessable_entity
    end

    def download_attachment
      authorize @ticket, :show?
      attachment = ActiveStorage::Attachment
        .where(record_type: "SupportMessage", record_id: @ticket.messages.select(:id), name: "attachments")
        .find(params[:attachment_id])
      response.headers["Cache-Control"] = "private, no-store"
      send_data attachment.download,
        filename: attachment.filename.to_s,
        type: "application/octet-stream",
        disposition: "attachment"
    end

    private
      def set_ticket
        @ticket = policy_scope(SupportTicket).find(params[:id])
      end

      def message_params
        params.require(:support_message).permit(:body, attachments: [])
      end
  end
end
