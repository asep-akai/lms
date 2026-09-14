require "test_helper"

class PermissionTest < ActiveSupport::TestCase
  test "every permission used by a policy exists in the catalog" do
    policy_keys = Dir[Rails.root.join("app/policies/*_policy.rb")].flat_map do |path|
      File.read(path).scan(/(?:permitted\?|can\?)\(\"([^\"]+)\"/).flatten
    end.uniq

    assert_empty policy_keys - Permission::CATALOG.keys
    assert_empty Permission::CATALOG.keys - Permission.pluck(:key)
  end

  test "organization permissions are grouped by focus in a stable order" do
    groups = Permission.organization_assignable.organization_groups

    assert_equal %w[Organization Members Courses Roles Audit], groups.map(&:first)
    assert_equal %w[courses.index courses.create courses.update courses.destroy course_enrollments.update materials.index materials.create materials.update materials.destroy quizzes.index quizzes.create quizzes.update quizzes.destroy quiz_attempts.index quiz_attempts.show quiz_attempts.review quiz_attempts.reset],
      groups.to_h.fetch("Courses").map(&:key)
  end

  test "console permissions are grouped by focus in a stable order" do
    groups = Permission.console_assignable.console_groups

    assert_equal [ "Console access", "Organizations", "Users", "Administrators", "Roles" ], groups.map(&:first)
    assert_equal %w[users.index users.create users.update users.destroy], groups.to_h.fetch("Users").map(&:key)
  end

  test "organization administrator role has every organization permission" do
    admin_role = organizations(:one).roles.find_by!(key: "admin")

    assert_equal Permission.organization_assignable.order(:key).pluck(:key), admin_role.permissions.order(:key).pluck(:key)
    assert_empty admin_role.permissions.where(key: Permission::CONSOLE_ONLY_KEYS)
  end
end
