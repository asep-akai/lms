require "application_system_test_case"

class AssignmentWorkflowTest < ApplicationSystemTestCase
  test "teacher assigns work and comments after the student submits" do
    teacher = create_member("teacher", "workflow-teacher@example.com", "Workflow Teacher")
    student = create_member("student", "workflow-student@example.com", "Workflow Student")
    second_student = create_member("student", "second-workflow-student@example.com", "Second Workflow Student")
    create_class_meeting(teacher, student)
    create_class_meeting(teacher, second_student)

    sign_in_as(teacher.user)
    visit organization_student_path(organizations(:one), student)
    click_link "Give assignment"

    student_picker = find("button[data-searchable-multiselect-target='button']")
    assert_text "Workflow Student", exact: false
    student_picker.click
    within "#assignment-student-options" do
      assert_checked_field "Workflow Student"
      assert_unchecked_field "Second Workflow Student"
      fill_in "Search students", with: "second-workflow"
      assert_text "Second Workflow Student"
      assert_no_text "Workflow Student", exact: true
      fill_in "Search students", with: ""
    end
    student_picker.click

    fill_in "Title", with: "Observation notes"
    fill_in "Description", with: "Write a short response and attach your notes."
    deadline_field = find_field("Deadline date and time")
    deadline = 2.days.from_now.in_time_zone(organizations(:one).timezone).strftime("%Y-%m-%dT%H:%M")
    page.execute_script("arguments[0].value = arguments[1]", deadline_field, deadline)
    attach_file "Assignment document (optional)", file_fixture("assignment.txt")
    click_button "Create assignment"

    assert_text "Assignment created and students notified."
    assert_text "Observation notes"
    assert_link "assignment.txt"

    click_button "Sign out"
    assert_field "Email"
    sign_in_as(student.user)
    click_link "Assignments"
    within "tr", text: "Observation notes" do
      click_link "View assignment"
    end

    fill_in "Written response", with: "These are my completed observation notes."
    attach_file "Documents", file_fixture("assignment.txt")
    click_button "Save draft"
    assert_text "Draft saved."
    assert_field "Written response", with: "These are my completed observation notes."
    assert_link "assignment.txt", count: 2

    click_button "Submit assignment"
    within("dialog[open]") do
      assert_text "You will not be able to change it afterward."
      click_button "Confirm"
    end
    assert_text "Assignment submitted."
    assert_text "Submitted work cannot be changed."
    assert_no_field "Written response"
    assert_link "assignment.txt", count: 2

    click_button "Sign out"
    assert_field "Email"
    sign_in_as(teacher.user)
    click_link "Assignments"
    within "tr", text: "Observation notes" do
      click_link "View assignment"
    end
    within "article", text: "Workflow Student" do
      assert_text "These are my completed observation notes."
      assert_link "assignment.txt"
      fill_in "Comment to student", with: "Good detail. Add one supporting example next time."
      click_button "Send comment"
    end

    assert_text "Comment sent to the student."
    assert_field "Comment to student", with: "Good detail. Add one supporting example next time."
  end

  test "student assignment screens remain usable at a narrow width" do
    teacher = create_member("teacher", "mobile-assignment-teacher@example.com", "Mobile Teacher")
    student = create_member("student", "mobile-assignment-student@example.com", "Mobile Student")
    create_class_meeting(teacher, student)
    assignment = organizations(:one).assignments.new(
      teacher_membership: teacher,
      title: "Mobile assignment",
      description: "Submit a response from any device.",
      deadline: 2.days.from_now
    )
    assignment.recipients.build(student_membership: student)
    assignment.save!
    sign_in_as(student.user)
    page.current_window.resize_to(500, 850)

    visit organization_assignments_path(organizations(:one))
    assert_text "Mobile assignment"
    assert_no_page_overflow
    assert_operator find_link("View assignment").native.size.height, :>=, 44

    click_link "View assignment"
    assert_no_page_overflow
    assert_operator find_button("Submit assignment").native.size.height, :>=, 44
  end

  test "teacher edits and cancels an assignment" do
    teacher = create_member("teacher", "editing-assignment-teacher@example.com", "Editing Teacher")
    student = create_member("student", "editing-assignment-student@example.com", "Editing Student")
    create_class_meeting(teacher, student)
    assignment = organizations(:one).assignments.new(
      teacher_membership: teacher,
      title: "Original assignment",
      description: "Original instructions.",
      deadline: 2.days.from_now
    )
    assignment.recipients.build(student_membership: student)
    assignment.save!
    sign_in_as(teacher.user)

    visit organization_assignment_path(organizations(:one), assignment)
    click_link "Edit assignment"
    fill_in "Title", with: "Updated assignment"
    fill_in "Description", with: "Updated instructions."
    click_button "Save changes"

    assert_text "Assignment updated and students notified."
    assert_text "Updated assignment"
    assert_text "Updated instructions."
    click_button "Cancel assignment"
    within("dialog[open]") do
      assert_text "Students will no longer be able to submit work."
      click_button "Confirm"
    end

    assert_text "Assignment cancelled. Students can no longer submit work."
    assert_text "Existing student work is preserved"
    assert_no_link "Edit assignment"
    assert_no_button "Cancel assignment"
  end

  private
    def sign_in_as(user)
      visit new_user_session_path
      fill_in "Email", with: user.email
      fill_in "Password", with: "password"
      click_button "Sign in"
      assert_text organizations(:one).name
    end

    def create_class_meeting(teacher, student)
      meeting = organizations(:one).class_meetings.new(
        teacher_membership: teacher,
        subject: "Science",
        topic: "Observation",
        starts_at: 1.day.ago,
        delivery_mode: "onsite"
      )
      meeting.student_memberships = [ student ]
      meeting.save!
    end

    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end

    def assert_no_page_overflow
      widths = page.evaluate_script("[document.documentElement.scrollWidth, window.innerWidth]")
      assert_operator widths.first, :<=, widths.last
    end
end
