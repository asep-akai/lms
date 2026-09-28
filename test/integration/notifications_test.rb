require "test_helper"
require "turbo/broadcastable/test_helper"

class NotificationsTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    @organization = organizations(:one)
    @teacher = create_member("teacher", "notification-teacher@example.com", "Notification Teacher")
    @student = create_member("student", "notification-student@example.com", "Notification Student")
    @other_student = create_member("student", "other-notification-student@example.com", "Other Student")
  end

  test "recipient lists unread notifications and opening one marks it read" do
    notification = InAppNotifier.deliver(
      recipient: @student,
      actor: @teacher,
      kind: "class_meeting_updated",
      title: "Class details updated",
      body: "English: Conversation practice",
      path: organization_class_meetings_path(@organization)
    )
    sign_in @student.user

    get organization_notifications_path(@organization)

    assert_response :success
    assert_select ".notification-count", "1"
    assert_select "details.notification-menu[data-controller='notification-menu']" do
      assert_select ".notification-popover strong", "Class details updated"
      assert_select "a", "View all notifications"
    end
    assert_select ".notification-row-unread" do
      assert_select ".badge-info", "New"
      assert_select "strong", "Class details updated"
    end

    get organization_notification_path(@organization, notification)

    assert_redirected_to organization_class_meetings_path(@organization)
    assert notification.reload.read?
  end

  test "recipient marks every notification as read" do
    2.times do |index|
      InAppNotifier.deliver(
        recipient: @student,
        actor: @teacher,
        kind: "assignment_updated",
        title: "Assignment updated #{index}",
        path: organization_assignments_path(@organization)
      )
    end
    sign_in @student.user

    patch mark_all_read_organization_notifications_path(@organization)

    assert_redirected_to organization_notifications_path(@organization)
    assert_empty @student.notifications.unread
  end

  test "another organization member cannot open a recipient notification" do
    notification = InAppNotifier.deliver(
      recipient: @student,
      actor: @teacher,
      kind: "assignment_updated",
      title: "Private update",
      path: organization_assignments_path(@organization)
    )
    sign_in @other_student.user

    get organization_notification_path(@organization, notification)

    assert_response :not_found
    assert_not notification.reload.read?
  end

  test "membership without a student or teacher role has no notification interface" do
    sign_in users(:one)

    get organization_path(@organization)
    assert_response :success
    assert_select "details.notification-menu", count: 0

    get organization_notifications_path(@organization)
    assert_redirected_to root_path
  end

  test "new notification broadcasts the recipient's unread count" do
    streams = capture_turbo_stream_broadcasts([ @organization, @student, :notifications ]) do
      InAppNotifier.deliver(
        recipient: @student,
        actor: @teacher,
        kind: "class_meeting_updated",
        title: "Class details updated",
        path: organization_class_meetings_path(@organization)
      )
    end

    assert_equal [ "replace" ], streams.map { |stream| stream["action"] }
    assert_equal "notification_indicator_membership_#{@student.id}", streams.first["target"]
    assert streams.first.at_css("[aria-label='1 unread notification']")
  end

  private
    def create_member(role_key, email, name)
      user = User.create!(email: email, name: name, password: "password123", password_confirmation: "password123")
      membership = @organization.memberships.create!(user: user, status: "active")
      membership.role_ids = [ @organization.roles.find_by!(key: role_key).id ]
      membership
    end
end
