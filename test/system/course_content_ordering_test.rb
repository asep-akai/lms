require "application_system_test_case"

class CourseContentOrderingTest < ApplicationSystemTestCase
  test "administrator moves a quiz between material modules" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    create_material(course, "Cell structure")
    create_material(course, "Cell function")
    quiz = course.quizzes.create!(title: "Cells check-in")

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_course_path(organizations(:one), course)

    assert_equal [
      "Module 1 · Material",
      "Module 2 · Material",
      "Module 3 · Quiz"
    ], all("[id^='course-content-'] p", text: /Module \d/).map(&:text)

    within "#course-content-#{course.course_contents.first.id}" do
      click_link "View material"
    end
    assert_link "Back to course", href: organization_course_path(organizations(:one), course)
    click_link "Back to course"

    within "#course-content-#{quiz.course_content.id}" do
      click_link "Manage quiz"
    end
    assert_link "Back to course", href: organization_course_path(organizations(:one), course)
    click_link "Back to course"

    within "#course-content-#{quiz.course_content.id}" do
      click_button "Move up"
    end

    assert_text "Course content reordered."
    assert_equal [
      "Module 1 · Material",
      "Module 2 · Quiz",
      "Module 3 · Material"
    ], all("[id^='course-content-'] p", text: /Module \d/).map(&:text)
  end

  test "student navigates adjacent modules outside an active quiz attempt" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    first_material = create_material(course, "Cell structure")
    quiz = course.quizzes.create!(title: "Cells check-in")
    quiz.questions.create!(question_type: "short_answer", content_html: "<p>Name an organelle.</p>", short_answer: "Mitochondrion", position: 1)
    second_material = create_material(course, "Cell function")

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"

    visit organization_course_material_path(organizations(:one), course, first_material, from: "course")
    within "nav[aria-label='Course module navigation']" do
      assert_button "Previous module", disabled: true
      click_link "Next module"
    end

    assert_current_path organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    assert_link "Start quiz"
    assert_selector "nav[aria-label='Course module navigation']"
    click_link "Start quiz"

    assert_no_selector "nav[aria-label='Course module navigation']"
    click_button "Submit"
    within "dialog[open]" do
      click_button "Confirm"
    end

    assert_text "Attempt submitted"
    within "nav[aria-label='Course module navigation']" do
      click_link "Next module"
    end
    assert_current_path organization_course_material_path(organizations(:one), course, second_material, from: "course")
    assert_text "Cell function"
    assert_link "Previous module"
  end

  private
    def create_material(course, title)
      material = course.materials.new(title: title)
      material.blocks.build(block_type: "text", body_html: "<p>#{title}</p>", position: 1)
      material.save!
      material
    end
end
