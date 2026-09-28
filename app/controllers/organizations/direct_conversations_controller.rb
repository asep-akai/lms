class Organizations::DirectConversationsController < Organizations::BaseController
  before_action :set_conversation, only: :show

  def index
    authorize DirectConversation
    load_conversations
    @contacts = DirectContactDirectory.new(Current.membership).contacts
  end

  def show
    authorize @conversation
    @conversation.mark_read_by!(Current.membership)
    Current.membership.notifications.unread.where(kind: "direct_message", notifiable: @conversation).update_all(read_at: Time.current)
    @other_participant = @conversation.other_participant(Current.membership)
    @messages = @conversation.direct_messages.includes(sender_membership: :user)
    @message = @conversation.direct_messages.new
  end

  def create
    contact = Current.organization.memberships.active.find(params.require(:contact_id))
    candidate = DirectConversation.between(Current.membership, contact)
    authorize candidate
    conversation = DirectConversation.between!(Current.membership, contact)

    redirect_to organization_direct_conversation_path(Current.organization, conversation)
  rescue ActiveRecord::RecordInvalid, Pundit::NotAuthorizedError
    redirect_to organization_direct_conversations_path(Current.organization), alert: "You can only message people connected to you through a class."
  end

  private
    def set_conversation
      @conversation = policy_scope(DirectConversation).find(params[:id])
    end

    def load_conversations
      @conversations = policy_scope(DirectConversation)
        .includes(participant_one_membership: :user, participant_two_membership: :user)
        .recent_first
    end
end
