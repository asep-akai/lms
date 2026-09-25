class SupportTicketMailer < ApplicationMailer
  SUBJECTS = {
    "created" => "New support ticket",
    "replied" => "New support ticket reply",
    "escalated" => "Support ticket escalated",
    "status_changed" => "Support ticket status updated"
  }.freeze

  def notification
    @ticket = params[:ticket]
    @recipient = params[:recipient]
    @event = params[:event]
    @actor = params[:actor]
    @message = params[:message]
    @ticket_url = ticket_url

    mail(to: @recipient.email, subject: "#{SUBJECTS.fetch(@event)}: #{@ticket.subject}")
  end

  private
    def ticket_url
      if params[:destination] == "console"
        console_support_ticket_url(@ticket)
      else
        organization_support_ticket_url(@ticket.organization, @ticket)
      end
    end
end
