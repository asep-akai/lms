require "test_helper"

class AuditEventPresenterTest < ActiveSupport::TestCase
  test "recorder preserves actor and subject identity snapshots" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")

    event = AuditRecorder.record!(
      action: "course.created",
      auditable: course,
      organization: organizations(:one),
      actor: users(:one)
    )

    assert_equal(
      { "type" => "User", "id" => users(:one).id, "name" => "Admin User", "email" => "one@example.com" },
      event.metadata.fetch("actor")
    )
    assert_equal(
      { "type" => "Course", "id" => course.id, "name" => "Biology" },
      event.metadata.fetch("subject")
    )

    course.destroy!
    presenter = AuditEventPresenter.new(event.reload)
    assert_equal "Biology", presenter.subject_name
    assert_equal "Course ##{course.id}", presenter.subject_reference
  end

  test "recorder normalizes changes and excludes sensitive or unchanged fields" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")

    event = AuditRecorder.record!(
      action: "course.updated",
      auditable: course,
      organization: organizations(:one),
      actor: users(:one),
      metadata: { password: "must-not-be-stored", note: "Requested by department lead" },
      changes: {
        name: [ "Science", "Biology" ],
        description: [ "Living systems.", "Living systems." ],
        password: [ "old-secret", "new-secret" ]
      }
    )

    assert_equal({ "name" => { "before" => "Science", "after" => "Biology" } }, event.metadata.fetch("changes"))
    assert_equal "Requested by department lead", event.metadata.fetch("note")
    assert_not event.metadata.key?("password")
    assert_not_includes event.metadata.to_json, "secret"
  end

  test "presenter supplies readable event and metadata details" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    event = travel_to(Time.utc(2026, 9, 9, 2, 30)) do
      AuditRecorder.record!(
        action: "course.enrollments_updated",
        auditable: course,
        organization: organizations(:one),
        actor: users(:one),
        metadata: { enrollment_count: 3, automatic: false },
        changes: {
          enrolled_students: [ [], [ "Student User (two@example.com)" ] ],
          status: [ nil, "active" ]
        }
      )
    end

    presenter = AuditEventPresenter.new(event)

    assert_equal "Updated course enrollments", presenter.description
    assert_equal "Admin User", presenter.actor_name
    assert_equal "one@example.com", presenter.actor_email
    assert_equal "Organization member", presenter.actor_type
    assert_equal "Biology", presenter.subject_name
    assert_equal(
      [
        [ "Enrolled students", "None", "Student User (two@example.com)" ],
        [ "Status", "Not set", "active" ]
      ],
      presenter.change_rows
    )
    assert_equal [ [ "Enrollment count", "3" ], [ "Automatic", "No" ] ], presenter.detail_rows
    assert presenter.details?
    assert_equal "9 Sep 2026, 09:30:00 WIB", presenter.occurred_at("Asia/Jakarta")
  end
end
