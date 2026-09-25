require "application_system_test_case"

class RoleModalTest < ApplicationSystemTestCase
  test "an organization administrator creates a role from the modal" do
    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name

    visit organization_roles_path(organizations(:one))
    click_link "New custom role"
    fill_in "Name", with: "Curriculum coordinator"
    fill_in "Key", with: "curriculum_coordinator"
    fill_in "Description", with: "Coordinates course content."
    click_button "Create Role"

    assert_no_text "Content missing"
    assert_no_selector "dialog[open]"
    assert_text "Role created."
    assert_text "Curriculum coordinator"
  end

  test "invalid and duplicate keys are explained without leaving the role modal" do
    organizations(:one).roles.create!(name: "Curriculum coordinator", key: "curriculum_coordinator")

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name
    visit organization_roles_path(organizations(:one))
    click_link "New custom role"

    fill_in "Name", with: "Another coordinator"
    fill_in "Key", with: "Wrong Key!"
    click_button "Create Role"

    assert_selector "dialog[open]"
    assert_text "Use lowercase letters and numbers separated by single underscores."
    assert_equal "Wrong Key!", find_field("Key").value

    fill_in "Key", with: "curriculum_coordinator"
    click_button "Create Role"

    assert_selector "dialog[open]"
    assert_text "This key is already used by another role. Choose a different key."
    assert_equal "curriculum_coordinator", find_field("Key").value
  end

  test "an organization administrator opens the role form in a modal" do
    role = organizations(:one).roles.create!(name: "Custom role", key: "custom_role")

    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_text organizations(:one).name

    visit organization_roles_path(organizations(:one))
    click_link "New custom role"

    assert_selector "dialog[open]"
    assert_text "New custom role"
    assert_equal "pointer", page.evaluate_script('getComputedStyle(document.querySelector("dialog"), "::backdrop").cursor')
    assert_equal "pointer", page.evaluate_script('getComputedStyle(document.querySelector("dialog button")).cursor')
    assert_equal "default", page.evaluate_script('getComputedStyle(document.querySelector("dialog")).cursor')

    centered = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const bounds = document.querySelector("dialog").getBoundingClientRect()
        const viewport = document.documentElement
        const horizontalOffset = Math.abs((bounds.left + bounds.width / 2) - viewport.clientWidth / 2)
        const verticalOffset = Math.abs((bounds.top + bounds.height / 2) - viewport.clientHeight / 2)
        return horizontalOffset < 2 && verticalOffset < 2
      })()
    JAVASCRIPT
    assert centered

    page.execute_script(<<~JAVASCRIPT)
      document.querySelector("dialog").dispatchEvent(new MouseEvent("click", {
        bubbles: true,
        clientX: 1,
        clientY: 1
      }))
    JAVASCRIPT
    assert_no_selector "dialog[open]"

    click_button "Delete"
    assert_selector "dialog[open]"
    assert_text "Delete this role?"

    page.execute_script(<<~JAVASCRIPT)
      document.querySelector("dialog").dispatchEvent(new MouseEvent("click", {
        bubbles: true,
        clientX: 1,
        clientY: 1
      }))
    JAVASCRIPT
    assert_no_selector "dialog[open]"
    assert Role.exists?(role.id)
  end
end
