require "application_system_test_case"

class ClassMeetingManagementTest < ApplicationSystemTestCase
  test "administrator schedules a class meeting" do
    teacher = create_member("teacher", "teacher@example.com", "Teacher One")
    student = create_member("student", "student-one@example.com", "Student One")

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_class_meetings_path(organizations(:one))
    click_link "Schedule class"

    fill_in "Subject", with: "Mathematics"
    fill_in "Topic", with: "Introduction to algebra"
    date_time_field = find_field("Date and time")
    page.execute_script("arguments[0].value = arguments[1]", date_time_field, "2026-10-10T08:30")
    select "Online", from: "Status"
    fill_in "Online meeting link", with: "https://meet.example.com/algebra"
    click_button "Choose a teacher"
    fill_in "Search teachers", with: "teacher@example.com"
    click_button "Teacher One"
    click_button "Select students"
    fill_in "Search students", with: "student-one@example.com"
    check "Student One"
    click_button "Done"
    click_button "Schedule class"

    assert_text "Class meeting scheduled. Email notifications have been queued."
    meeting = ClassMeeting.order(:id).last
    assert_current_path organization_class_meeting_path(organizations(:one), meeting)
    assert_text "Mathematics · Meeting 1"
    assert_text "Introduction to algebra"
    assert_text teacher.user.name
    assert_text student.user.name
    assert_link "Join online class", href: "https://meet.example.com/algebra"
  end

  test "student opens a calendar day and navigates between months" do
    teacher = create_member("teacher", "calendar-teacher@example.com", "Calendar Teacher")
    student = create_member("student", "calendar-student@example.com", "Calendar Student")
    meeting = organizations(:one).class_meetings.new(
      teacher_membership: teacher,
      subject: "Biology",
      topic: "Cell structure",
      starts_at: Time.utc(2026, 10, 10, 8, 30),
      delivery_mode: "onsite"
    )
    meeting.student_memberships = [ student ]
    meeting.save!

    visit new_user_session_path
    fill_in "Email", with: student.user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_class_meetings_path(organizations(:one), month: "2026-10")

    assert_text "October 2026"
    assert_text "Biology"
    find("a[aria-label='View classes on 10 October 2026']").click
    assert_selector "dialog[open]"
    within("dialog") do
      assert_text "Saturday, 10 October 2026"
      assert_text "Cell structure"
    end
    click_button "Close"

    click_link "Next →"
    assert_text "November 2026"
    assert_link "Today"
  end

  test "student searches their class history" do
    teacher = create_member("teacher", "history-teacher@example.com", "History Teacher")
    student = create_member("student", "history-student@example.com", "History Student")
    meeting = organizations(:one).class_meetings.new(
      teacher_membership: teacher,
      subject: "Literature",
      topic: "Poetry analysis",
      starts_at: 2.days.ago,
      delivery_mode: "onsite"
    )
    meeting.student_memberships = [ student ]
    meeting.save!

    visit new_user_session_path
    fill_in "Email", with: student.user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_class_meetings_path(organizations(:one))
    click_link "Class history"

    assert_text "Poetry analysis"
    fill_in "Search by subject, topic, and teacher name", with: "History Teacher"
    click_button "Search"

    assert_text "Search results"
    assert_text "Literature"
    assert_text "History Teacher"
    click_link "View class"
    assert_text "Poetry analysis"
    assert_link "Back to class history"
    click_link "Back to class history"
    assert_field "Search by subject, topic, and teacher name", with: "History Teacher"
    assert_text "Poetry analysis"
  end

  test "student submits and views feedback from class history" do
    teacher = create_member("teacher", "feedback-teacher@example.com", "Feedback Teacher")
    student = create_member("student", "feedback-student@example.com", "Feedback Student")
    meeting = organizations(:one).class_meetings.new(
      teacher_membership: teacher,
      subject: "Biology",
      topic: "Cell structure",
      starts_at: 2.hours.ago,
      delivery_mode: "onsite"
    )
    meeting.student_memberships = [ student ]
    meeting.save!

    visit new_user_session_path
    fill_in "Email", with: student.user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit history_organization_class_meetings_path(organizations(:one))

    click_link "Give feedback"
    assert_selector "dialog[open]"
    within("dialog") do
      find("label", text: "5", exact_text: true).click
      fill_in "Comment (optional)", with: "The examples made the topic easy to follow."
      click_button "Submit feedback"
    end

    assert_current_path history_organization_class_meetings_path(organizations(:one))
    assert_text "Feedback submitted."
    click_link "View your feedback"
    assert_selector "dialog[open]"
    within("dialog") do
      assert_text "5/5"
      assert_text "The examples made the topic easy to follow."
    end
  end

  test "administrator filters feedback and opens its private details" do
    teacher = create_member("teacher", "admin-feedback-teacher@example.com", "Feedback Teacher")
    student = create_member("student", "admin-feedback-student@example.com", "Feedback Student")
    meeting = organizations(:one).class_meetings.new(
      teacher_membership: teacher,
      subject: "Biology",
      topic: "Cell structure",
      starts_at: 2.hours.ago,
      delivery_mode: "onsite"
    )
    meeting.student_memberships = [ student ]
    meeting.save!
    teacher_feedback = meeting.feedbacks.create!(
      author_membership: teacher,
      author_role: "teacher",
      rating: 4,
      internal_feedback: "Spend more time checking prior knowledge.",
      feedback_to_student: "Good participation today.",
      topics_discussed: "Cell structure",
      next_topics: "Cell division"
    )
    meeting.feedbacks.create!(
      author_membership: student,
      author_role: "student",
      rating: 5,
      comment: "The diagrams were useful."
    )

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_class_feedback_path(organizations(:one))

    assert_text "2 responses"
    select "Teachers", from: "Feedback from"
    click_button "Apply filters"

    assert_selector "tr[data-feedback-id='#{teacher_feedback.id}']"
    assert_selector "tr[data-feedback-id]", count: 1
    click_link "View details"

    assert_selector "dialog[open]"
    within("dialog") do
      assert_text "Internal feedback"
      assert_text "Spend more time checking prior knowledge."
    end
  end

  private
    def create_member(role_key, email, name)
      user = User.create!(name: name, email: email, password: "password", status: "active")
      membership = organizations(:one).memberships.create!(user: user, status: "active")
      membership.role_ids = [ organizations(:one).roles.find_by!(key: role_key).id ]
      membership
    end
end
