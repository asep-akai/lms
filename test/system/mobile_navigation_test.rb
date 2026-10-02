require "application_system_test_case"

class MobileNavigationTest < ApplicationSystemTestCase
  test "student can use the mobile menu with keyboard and return to desktop navigation" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    visit new_user_session_path
    fill_in "Email", with: users(:two).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
    visit organization_path(organizations(:one))
    check_mobile_menu

    click_button "Menu"
    within "nav[aria-label='Main navigation']" do
      assert_link "Evaluation"
      assert_no_link "Users"
      assert_no_link "Grading"
      click_link "Messages"
    end
    assert_current_path organization_direct_conversations_path(organizations(:one))
    assert_selector "button[aria-controls='primary-navigation'][aria-expanded='false']"

    page.current_window.resize_to(1400, 1000)
    assert_no_button "Menu"
    assert_link "Support"
    assert_no_overflow
    page.current_window.resize_to(500, 850)
    assert_selector "button[aria-controls='primary-navigation'][aria-expanded='false']"
    assert_no_selector "nav[aria-label='Main navigation']"
  end

  test "organization administrator can reach management links on mobile" do
    visit new_user_session_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
    visit organization_path(organizations(:one))
    check_mobile_menu
    click_button "Menu"
    within "nav[aria-label='Main navigation']" do
      assert_link "Grading"
      assert_link "Users"
      click_link "Students"
    end
    assert_current_path organization_students_path(organizations(:one))
  end

  test "console menu exposes console destinations at phone widths" do
    visit console_root_path
    fill_in "Email", with: admins(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
    assert_current_path console_root_path
    check_mobile_menu
    click_button "Menu"
    within "nav[aria-label='Main navigation']" do
      assert_link "Administrators"
      click_link "Organizations"
    end
    assert_current_path console_organizations_path
  end

  private
    def check_mobile_menu
      page.current_window.resize_to(500, 850)
      assert_selector "button[aria-controls='primary-navigation'][aria-expanded='false']"
      assert_no_selector "nav[aria-label='Main navigation']"
      find_button("Menu").send_keys(:enter)
      assert_selector "button[aria-controls='primary-navigation'][aria-expanded='true']"
      assert_selector "nav[aria-label='Main navigation']"
      assert_no_overflow
      page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-navigation.png"))
      assert_operator find_button("Menu").native.size.height, :>=, 44
      find_button("Menu").send_keys(:tab)
      assert_equal "nav-link", page.evaluate_script("document.activeElement.className")
      page.driver.browser.action.send_keys(:escape).perform
      assert_selector "button[aria-controls='primary-navigation'][aria-expanded='false']"
      assert_equal "Menu", page.evaluate_script("document.activeElement.textContent")
      click_button "Menu"
      find(".topbar-inner").click(x: 1, y: 1)
      assert_selector "button[aria-controls='primary-navigation'][aria-expanded='false']"
      check_phone_width
    end

    def check_phone_width
      [ 390, 320 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: true)
        click_button "Menu"
        assert_selector "nav[aria-label='Main navigation']"
        assert page.evaluate_script("document.querySelector('header').scrollWidth <= window.innerWidth")
        page.save_screenshot(Rails.root.join("tmp/screenshots/mobile-navigation-#{width}.png"))
        page.driver.browser.action.send_keys(:escape).perform
        assert_selector "button[aria-controls='primary-navigation'][aria-expanded='false']"
      end
    ensure
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end

    def assert_no_overflow
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    end
end
