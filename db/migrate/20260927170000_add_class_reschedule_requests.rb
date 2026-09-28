class AddClassRescheduleRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :reschedule_quota, :integer, default: 0, null: false
    add_check_constraint :memberships, "reschedule_quota >= 0", name: "memberships_reschedule_quota_nonnegative"

    add_column :class_meetings, :cancelled_at, :datetime
    add_reference :class_meetings,
      :cancelled_by_membership,
      foreign_key: { to_table: :memberships },
      index: true
    add_index :class_meetings, :cancelled_at
  end
end
