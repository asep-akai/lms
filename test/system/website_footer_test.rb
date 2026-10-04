require "application_system_test_case"

class WebsiteFooterSystemTest < ApplicationSystemTestCase
  setup { @website = LandingPageStarter.call! }

  test "editor configures footer links previews and publishes on desktop and mobile" do
    visit console_root_path
    fill_in "Email", with: admins(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Website", exact: true
    fill_in "Footer text", with: "Learning with your team."
    fill_in "Copyright line (optional)", with: "Footer test content"
    select "Forest", from: "Footer background"
    uncheck "Show workspace link in footer"
    click_button "Save footer to draft"
    assert_text "Website settings saved to draft."
    click_link "Add footer link"
    assert_selector "h1", text: "Add footer link"
    fill_in "Link label", with: "Our platform"
    select @website.sections.third.heading, from: "Page section"
    click_button "Save navigation link"
    within "#footer-links" do
      assert_text "Our platform"
      click_link "Edit", exact: true
    end
    fill_in "Link label", with: "Platform overview"
    click_button "Save navigation link"
    click_link "Preview draft"
    assert_selector "footer.marketing-theme-forest", text: "Learning with your team."
    assert_selector "footer", text: "Footer test content"
    within "footer" do
      assert_no_link "Console", exact: true
      click_link "Platform overview"
    end
    assert_current_path(/#section-#{@website.sections.third.id}\z/, url: true)
    click_link "Back to website editor"
    click_button "Publish draft"
    within "dialog[open]" do
      click_button "Confirm"
    end
    assert_text "Website published."
    click_link "View live page"
    assert_selector "footer", text: "Learning with your team."
    [ 1400, 390, 320 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: width < 500)
      find("footer").execute_script("this.scrollIntoView({ block: 'center' })")
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      link = find("footer a")
      assert_operator link.native.size.height, :>=, 44
      link.send_keys([ :shift, :tab ])
      page.driver.browser.action.send_keys(:tab).perform
      assert_equal "Platform overview", page.evaluate_script("document.activeElement.textContent")
      assert_equal "3px", link.evaluate_script("getComputedStyle(this).outlineWidth")
      page.save_screenshot(Rails.root.join("tmp/screenshots/website-footer-#{width}.png"))
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
