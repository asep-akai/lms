require "test_helper"

class PermissionTest < ActiveSupport::TestCase
  test "every permission used by a policy exists in the catalog" do
    policy_keys = Dir[Rails.root.join("app/policies/*_policy.rb")].flat_map do |path|
      File.read(path).scan(/(?:permitted\?|can\?)\(\"([^\"]+)\"/).flatten
    end.uniq

    assert_empty policy_keys - Permission::CATALOG.keys
    assert_empty Permission::CATALOG.keys - Permission.pluck(:key)
  end
end
