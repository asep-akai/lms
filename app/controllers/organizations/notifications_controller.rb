class Organizations::NotificationsController < Organizations::BaseController
  def index
    authorize Notification
    notifications = policy_scope(Notification).includes(:actor_membership, :notifiable).recent
    @pagination, @notifications = paginate(notifications)
  end

  def show
    notification = policy_scope(Notification).find(params[:id])
    authorize notification
    notification.mark_read!
    redirect_to notification.path, allow_other_host: false
  end

  def mark_all_read
    authorize Notification, :mark_all_read?
    policy_scope(Notification).unread.update_all(read_at: Time.current)
    redirect_to organization_notifications_path(Current.organization), notice: "Notifications marked as read."
  end
end
