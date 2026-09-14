require "application_system_test_case"

class AuditLogTest < ApplicationSystemTestCase
  teardown { page.current_window.resize_to(1400, 1000) }

  test "organization administrator inspects audit event details" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    AuditRecorder.record!(
      action: "course.enrollments_updated",
      auditable: course,
      organization: organizations(:one),
      actor: users(:one),
      metadata: { enrollment_count: 2 },
      changes: { enrolled_students: [ [], [ "Student User (two@example.com)" ] ] }
    )

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Audit log"

    assert_text "Updated course enrollments"
    assert_text "Admin User"
    assert_text "Biology"
    find("summary", text: "View details").click
    assert_text "Changed field"
    assert_text "Before"
    assert_text "After"
    assert_text "Student User (two@example.com)"
    assert_text "Enrollment count"
    assert_text "2"

    page.current_window.resize_to(500, 900)
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, page.evaluate_script("window.innerWidth")
  end
end
