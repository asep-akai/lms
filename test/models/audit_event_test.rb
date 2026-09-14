require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  test "supports users and administrators as actors" do
    event = AuditEvent.create!(actor: admins(:one), action: "console.test", occurred_at: Time.current)
    assert_equal admins(:one), event.actor
  end
end
