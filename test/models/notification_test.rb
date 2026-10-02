require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "notification paths stay on this application" do
    [ "https://outside.test", "//outside.test", "/\\outside.test", "/courses\nhttps://outside.test", "/courses\rredirect", "/courses\\bad" ].each do |path|
      notification = Notification.new(path: path)
      notification.valid?
      assert notification.errors[:path].any?, "Expected rejection of #{path.inspect}"
    end
    notification = Notification.new(path: "/organizations/school/courses?search=biology")
    notification.valid?
    assert_empty notification.errors[:path]
  end
end
