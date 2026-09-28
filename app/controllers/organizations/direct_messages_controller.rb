class Organizations::DirectMessagesController < Organizations::BaseController
  def create
    conversation = policy_scope(DirectConversation).find(params[:direct_conversation_id])
    @message = conversation.direct_messages.new(message_params.merge(sender_membership: Current.membership))
    authorize @message

    if @message.save
      conversation.mark_read_by!(Current.membership)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to organization_direct_conversation_path(Current.organization, conversation) }
      end
    else
      @conversation = conversation
      @other_participant = conversation.other_participant(Current.membership)
      @messages = conversation.direct_messages.includes(sender_membership: :user)
      render "organizations/direct_conversations/show", status: :unprocessable_entity
    end
  end

  private
    def message_params
      params.require(:direct_message).permit(:body)
    end
end
