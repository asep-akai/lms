require "application_system_test_case"

class RoleModalTest < ApplicationSystemTestCase
  test "an administrator opens the role form in a modal" do
    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"

    click_link organizations(:one).name
    visit organization_roles_path(organizations(:one))
    click_link "New custom role"

    assert_selector "dialog[open]"
    assert_text "New custom role"
  end
end
