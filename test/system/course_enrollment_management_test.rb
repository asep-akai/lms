require "application_system_test_case"

class CourseEnrollmentManagementTest < ApplicationSystemTestCase
  test "administrator searches for and enrolls a student in a course" do
    student = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name

    visit enrollments_organization_course_path(organizations(:one), course)
    click_button "Select students"
    fill_in "Search students", with: users(:two).email
    check users(:two).name
    assert_text "1 selected"
    click_button "Done"
    click_button "Save enrollments"

    assert_current_path organization_course_path(organizations(:one), course)
    assert_text "Course enrollments updated."
    assert course.course_enrollments.exists?(membership: student)
  end
end
