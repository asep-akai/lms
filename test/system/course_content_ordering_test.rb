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

    section = find("#course-section-#{course.default_section.id}")
    assert section.evaluate_script("this.open")
    within section do
      find("summary").click
    end
    assert_not section.evaluate_script("this.open")
    within section do
      find("summary").click
    end

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
      controls = all("a, button", minimum: 3).map(&:text)
      assert_equal [ "Previous module", "Finish", "Next module" ], controls
      click_button "Finish"
    end

    assert_text "Material finished."
    within "nav[aria-label='Course module navigation']" do
      click_button "Mark incomplete"
    end
    assert_text "Material marked incomplete."
    assert_button "Finish"

    within "nav[aria-label='Course module navigation']" do
      click_link "Next module"
    end

    assert_current_path organization_course_quiz_path(organizations(:one), course, quiz, from: "course")
    assert_link "Start quiz"
    assert_selector "nav[aria-label='Course module navigation']"
    click_link "Start quiz"

    using_wait_time(8) do
      within "dialog[open][aria-label='Quiz connection test']" do
        assert_text "Testing your connection"
        find("[data-quiz-connection-check-target='proceed']", visible: true).click
      end
    end

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

  test "student expands and collapses course sections" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology sections", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    first_section = course.default_section
    first_section.update!(name: "Foundations")
    second_section = course.course_sections.create!(name: "Cell division", position: 2)
    create_material(course, "Cell structure")
    second_material = course.materials.new(title: "Mitosis", course_section_id: second_section.id)
    second_material.blocks.build(block_type: "text", body_html: "<p>Mitosis</p>", position: 1)
    second_material.save!

    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text "Organizations"
    visit organization_course_path(organizations(:one), course)

    first_details = find("#course-section-#{first_section.id}")
    second_details = find("#course-section-#{second_section.id}")
    assert first_details.evaluate_script("this.open")
    assert_not second_details.evaluate_script("this.open")

    within first_details do
      find("summary").click
    end
    assert_not first_details.evaluate_script("this.open")

    within second_details do
      find("summary").click
      assert_text "Mitosis"
    end
    assert second_details.evaluate_script("this.open")
  end

  private
    def create_material(course, title)
      material = course.materials.new(title: title)
      material.blocks.build(block_type: "text", body_html: "<p>#{title}</p>", position: 1)
      material.save!
      material
    end
end
