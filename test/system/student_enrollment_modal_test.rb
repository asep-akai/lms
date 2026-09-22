require "application_system_test_case"

class StudentEnrollmentModalTest < ApplicationSystemTestCase
  test "administrator enrolls a student without opening the progress report" do
    student = organizations(:one).memberships.create!(user: users(:two), status: "active")
    student.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_students_path(organizations(:one))

    within "tr", text: users(:two).name do
      click_link "Enroll in course"
    end

    assert_selector "dialog[open]", text: "Enroll #{users(:two).name}"
    within "dialog[open]" do
      select "Biology", from: "Course"
      click_button "Enroll student"
    end

    assert_current_path organization_students_path(organizations(:one))
    assert_text "Student enrolled in Biology."
    assert course.course_enrollments.exists?(membership: student)
  end
end
