require "test_helper"
require "turbo/broadcastable/test_helper"

class DirectConversationsTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    @organization = organizations(:one)
    @teacher = create_member("teacher", "chat-teacher@example.com", "Chat Teacher")
    @student = create_member("student", "chat-student@example.com", "Chat Student")
    @peer = create_member("student", "chat-peer@example.com", "Chat Peer")
    @unconnected = create_member("student", "not-connected@example.com", "Not Connected")
    create_meeting
  end

  test "teacher sees only students from classes they teach" do
    sign_in @teacher.user

    get organization_direct_conversations_path(@organization)

    assert_response :success
    assert_select "h1", "Messages"
    assert_select "strong", @student.user.name
    assert_select "strong", @peer.user.name
    assert_select "strong", { text: @unconnected.user.name, count: 0 }
  end

  test "student sees the teacher and peers from the same class" do
    sign_in @student.user

    get organization_direct_conversations_path(@organization)

    assert_response :success
    assert_select "strong", @teacher.user.name
    assert_select "strong", @peer.user.name
    assert_select "strong", { text: @unconnected.user.name, count: 0 }
  end

  test "connected users create a conversation and exchange escaped messages" do
    sign_in @student.user

    assert_difference "DirectConversation.count", 1 do
      post organization_direct_conversations_path(@organization), params: { contact_id: @teacher.id }
    end

    conversation = DirectConversation.order(:id).last
    assert_redirected_to organization_direct_conversation_path(@organization, conversation)

    assert_difference "DirectMessage.count", 1 do
      post organization_direct_conversation_direct_messages_path(@organization, conversation), params: {
        direct_message: { body: "Hello <script>alert('no')</script>" }
      }
    end

    assert_redirected_to organization_direct_conversation_path(@organization, conversation)
    follow_redirect!
    assert_response :success
    assert_select ".chat-message-body", text: /Hello.*alert\('no'\)/m do
      assert_select "script", count: 0
    end

    sign_in @teacher.user
    get organization_direct_conversation_path(@organization, conversation)
    assert_response :success
    assert_select "h1", @student.user.name
  end

  test "sending with Turbo immediately appends the message and resets the composer" do
    conversation = DirectConversation.between!(@teacher, @student)
    sign_in @student.user

    recipient_streams = capture_turbo_stream_broadcasts([ conversation, @teacher ]) do
      post organization_direct_conversation_direct_messages_path(@organization, conversation),
        params: { direct_message: { body: "Visible without reloading" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action='append'][target='messages_direct_conversation_#{conversation.id}']" do
      assert_select ".chat-message-body", text: /Visible without reloading/
    end
    assert_select "turbo-stream[action='replace'][target='new_direct_message']"
    assert_equal %w[remove append], recipient_streams.map { |stream| stream["action"] }
    assert_includes recipient_streams.last.text, "Visible without reloading"
    directory_streams = capture_turbo_stream_broadcasts([ @organization, @teacher, :direct_conversations ])
    assert_equal [ "replace" ], directory_streams.map { |stream| stream["action"] }
    assert_equal "direct_conversation_#{conversation.id}", directory_streams.first["target"]
    assert_includes directory_streams.first.text, "New message"
    notification = @teacher.notifications.find_by!(kind: "direct_message", notifiable: conversation)
    assert_equal "New message from #{@student.user.name}", notification.title
    assert_empty @student.notifications.where(kind: "direct_message", notifiable: conversation)

    get organization_direct_conversations_path(@organization)
    assert_select "a#direct_conversation_#{conversation.id}" do
      assert_select ".badge-info", { text: "New message", count: 0 }
    end
  end

  test "recipient sees a new message marker until opening the conversation" do
    conversation = DirectConversation.between!(@teacher, @student)
    sign_in @student.user
    post organization_direct_conversation_direct_messages_path(@organization, conversation), params: {
      direct_message: { body: "Please review this" }
    }

    sign_in @teacher.user
    get organization_direct_conversations_path(@organization)
    assert_select "a#direct_conversation_#{conversation.id}" do
      assert_select ".badge-info", "New message"
    end

    get organization_direct_conversation_path(@organization, conversation)
    assert_response :success
    get organization_direct_conversations_path(@organization)
    assert_select "a#direct_conversation_#{conversation.id}" do
      assert_select ".badge-info", { text: "New message", count: 0 }
    end
  end

  test "an unconnected member cannot create or open a conversation" do
    sign_in @unconnected.user

    assert_no_difference "DirectConversation.count" do
      post organization_direct_conversations_path(@organization), params: { contact_id: @teacher.id }
    end
    assert_redirected_to organization_direct_conversations_path(@organization)

    conversation = DirectConversation.between!(@teacher, @student)
    get organization_direct_conversation_path(@organization, conversation)
    assert_response :not_found
  end

  test "conversation access ends when the class connection is removed" do
    conversation = DirectConversation.between!(@teacher, @student)
    ClassMeetingStudent.where(membership: @student).delete_all
    sign_in @student.user

    get organization_direct_conversations_path(@organization)
    assert_response :success
    assert_select "a[href='#{organization_direct_conversation_path(@organization, conversation)}']", count: 0

    get organization_direct_conversation_path(@organization, conversation)
    assert_response :not_found
  end

  private
    def create_meeting
      meeting = @organization.class_meetings.new(
        teacher_membership: @teacher,
        subject: "English",
        topic: "Conversation practice",
        starts_at: 2.days.from_now,
        delivery_mode: "onsite"
      )
      meeting.student_memberships = [ @student, @peer ]
      meeting.save!
      meeting
    end

    def create_member(role_key, email, name)
      user = User.create!(email: email, name: name, password: "password123", password_confirmation: "password123")
      membership = @organization.memberships.create!(user: user, status: "active")
      membership.role_ids = [ @organization.roles.find_by!(key: role_key).id ]
      membership
    end
end
