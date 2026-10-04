require "application_system_test_case"

class WebsiteNavigationSystemTest < ApplicationSystemTestCase
  setup { @website = LandingPageStarter.call! }

  test "editor adds renames reorders hides and removes navigation links" do
    visit console_root_path
    fill_in "Email", with: admins(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
    visit console_website_path
    click_link "Add navigation link"
    fill_in "Link label", with: "About us"
    select @website.sections.second.heading, from: "Page section"
    click_button "Save navigation link"
    assert_text "Navigation link added to draft."
    item = @website.navigation_items.find_by!(label: "About us")
    within("#landing_navigation_item_#{item.id}") { click_button "Move up" }
    within "section[aria-label='Top-bar navigation'] ol li:first-child" do
      assert_text "About us"
    end
    within("#landing_navigation_item_#{item.id}") { click_link "Edit" }
    fill_in "Link label", with: "Our approach"
    click_button "Save navigation link"
    assert_text "Navigation link saved to draft."
    click_link "Preview draft"
    within "nav[aria-label='Website navigation']" do
      assert_link "Our approach"
      assert_link "The platform"
    end
    click_link "Back to website editor"
    within("#landing_navigation_item_#{item.id}") { click_link "Edit" }
    uncheck "Show in navigation"
    click_button "Save navigation link"
    assert_text "Navigation link saved to draft."
    within "section[aria-label='Top-bar navigation'] ol li:first-child" do
      assert_text "Hidden"
    end
    within("#landing_navigation_item_#{item.id}") { click_button "Remove" }
    within("dialog[open]") { click_button "Confirm" }
    assert_text "Navigation link removed from draft."
    assert_no_selector "#landing_navigation_item_#{item.id}"
  end

  test "several links work on desktop and in the keyboard accessible mobile menu" do
    @website.sections.where.not(layout: "hero").limit(4).each_with_index do |section, index|
      @website.navigation_items.create!(label: "Section #{index + 1}", landing_section: section, position: index + 1)
    end
    @website.publish!(actor: admins(:one))
    visit landing_path
    assert_link "The platform"
    assert_link "Section 4"
    assert_no_button "Menu"
    page.save_screenshot(Rails.root.join("tmp/screenshots/website-navigation-desktop.png"))
    [ 390, 320, 700 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: true)
      assert_no_selector "nav[aria-label='Website navigation']"
      find_button("Menu").send_keys(:enter)
      assert_selector "button[aria-expanded='true']"
      within "nav[aria-label='Website navigation']" do
        assert_link "Section 4"
        assert_operator find_link("Section 4").native.size.height, :>=, 44
      end
      assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")
      page.save_screenshot(Rails.root.join("tmp/screenshots/website-navigation-#{width}.png"))
      page.driver.browser.action.send_keys(:escape).perform
      assert_equal "Menu", page.evaluate_script("document.activeElement.textContent")
      click_button "Menu"
      click_link "Section 4"
      assert_no_selector "nav[aria-label='Website navigation']"
      target = @website.navigation_items.find_by!(label: "Section 4").landing_section
      assert_current_path(/#section-#{target.id}\z/, url: true)
      visit landing_path
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
