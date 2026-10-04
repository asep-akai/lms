require "application_system_test_case"

class WebsiteSystemTest < ApplicationSystemTestCase
  setup { @website = LandingPageStarter.call! }

  test "default homepage prioritizes the workspace after login and welcome stays available" do
    visit root_path
    assert_selector "h1", text: "Good teaching deserves a better workspace."
    click_link "The platform", exact: true
    assert_current_path(/#section-starter-3\z/, url: true)
    click_link "Kelasona", exact: true
    assert_current_path landing_path
    click_link "Sign in", exact: true
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path organization_path(organizations(:one))
    visit root_path
    assert_current_path organization_path(organizations(:one))
    visit landing_path
    assert_selector "h1", text: "Good teaching deserves a better workspace."
    click_link "Open workspace", exact: true
    assert_current_path organization_path(organizations(:one))
  end

  test "console editor changes illustration and image placement in draft" do
    visit console_root_path
    fill_in "Email", with: admins(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
    visit root_path
    assert_current_path console_root_path
    click_link "Website", exact: true
    section = @website.sections.find_by!(illustration: "course-materials")
    within "#landing_section_#{section.id}" do
      click_link "Edit", exact: true
    end
    assert_selector ".website-image-preview img[src*='course-materials-v1']"
    assert_text "Built-in illustration: Organized learning materials"
    select "No illustration", from: "Built-in illustration (optional)"
    assert_text "No image selected. This section will be text-only."
    assert_no_selector ".website-image-preview img"
    select "Essay and audio feedback", from: "Built-in illustration (optional)"
    assert_selector(".website-image-preview img[src*='review-feedback-v1']") { |image| image.evaluate_script("this.complete && this.naturalWidth > 0") }
    assert_text "Built-in illustration: Essay and audio feedback"
    select "Left of text", from: "Image placement"
    select "Forest", from: "Background style"
    click_button "Save section to draft"
    click_link "Preview draft"
    assert_selector "#section-#{section.id}.marketing-theme-forest"
    assert_selector "#section-#{section.id} .marketing-image-left img[src*='review-feedback-v1']"
    assert_illustrations_loaded
    click_link "Open console", exact: true
    assert_current_path console_root_path
  end

  test "all background presets work across layouts with readable text buttons and narrow screens" do
    LandingSectionBackgrounds::STYLES.each do |style|
      @website.sections.each { |section| section.update!(background_style: style, button_label: "Sign in", button_url: "/users/sign_in") }
      @website.publish!(actor: admins(:one))
      visit landing_path
      assert_selector "main section.marketing-theme-#{style}", count: 6
      [ 1400, 390, 320 ].each do |width|
        page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 1000, deviceScaleFactor: 1, mobile: width < 500)
        assert_no_overflow
        all("main .marketing-button").each do |button|
          assert_operator button.native.size.height, :>=, 44
          assert_operator button.evaluate_script(<<~JS), :>=, 4.5
            (() => {
              const luminance = (rgb) => {
                const c = rgb.match(/[\\d.]+/g).slice(0, 3).map(v => {
                  v = Number(v) / 255;
                  return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
                });
                return c[0] * .2126 + c[1] * .7152 + c[2] * .0722;
              };
              const css = getComputedStyle(this);
              const values = [luminance(css.color), luminance(css.backgroundColor)].sort((a, b) => a - b);
              return (values[1] + .05) / (values[0] + .05);
            })()
          JS
        end
      end
      page.save_screenshot(Rails.root.join("tmp/screenshots/website-theme-#{style}.png"))
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "image preview shows upload precedence removal fallback and file errors" do
    section = @website.sections.find_by!(illustration: "course-materials")
    section.update!(image_alt: "Saved upload description")
    File.open(Rails.root.join("app/assets/images/marketing/review-feedback-v1.jpg")) do |file|
      section.image.attach(io: file, filename: "uploaded-feedback.jpg", content_type: "image/jpeg")
    end
    visit console_root_path
    fill_in "Email", with: admins(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    visit edit_console_website_section_path(section)
    assert_text "Uploaded image: uploaded-feedback.jpg"
    assert_selector(".website-image-preview img") { |image| image.evaluate_script("this.complete && this.naturalWidth > 0") }
    select "No illustration", from: "Built-in illustration (optional)"
    assert_text "Uploaded image: uploaded-feedback.jpg"
    check "Remove uploaded image and use the selected illustration"
    assert_text "No image selected. This section will be text-only."
    select "Organized learning materials", from: "Built-in illustration (optional)"
    assert_selector ".website-image-preview img[src*='course-materials-v1']"
    uncheck "Remove uploaded image and use the selected illustration"
    attach_file "Upload a replacement image (optional)", Rails.root.join("test/fixtures/files/assignment.txt")
    assert_text "Choose a JPEG, PNG or WebP up to 5 MB."
    attach_file "Upload a replacement image (optional)", Rails.root.join("app/assets/images/marketing/course-materials-v1.jpg")
    assert_text "New upload (not saved): course-materials-v1.jpg"
    assert_selector(".website-image-preview img[src^='blob:']") { |image| image.evaluate_script("this.complete && this.naturalWidth > 0") }
    fill_in "Heading", with: ""
    click_button "Save section to draft"
    assert_current_path edit_console_website_section_path(section)
    fill_in "Heading", with: section.heading
    click_button "Save section to draft"
    assert_current_path console_website_path
    visit edit_console_website_section_path(section)
    assert_text "Uploaded image: course-materials-v1.jpg"
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 320, height: 844, deviceScaleFactor: 1, mobile: true)
    find(".website-image-preview").execute_script("this.scrollIntoView({ block: 'center' })")
    assert_no_overflow
    page.save_screenshot(Rails.root.join("tmp/screenshots/website-image-editor-320.png"))
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "console manages draft previews and confirms publishing" do
    visit console_root_path
    fill_in "Email", with: admins(:one).email
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_button "Sign out"
    click_link "Website", exact: true
    click_link "Add section"
    fill_in "Heading", with: "Our learning approach"
    fill_in "Description", with: "Content written by our team."
    click_button "Save section to draft"
    assert_text "Our learning approach"
    click_link "Preview draft"
    assert_text "Draft preview. Not visible to visitors."
    assert_selector "h2", text: "Our learning approach"
    click_link "Back to website editor"
    click_button "Publish draft"
    within "dialog[open]" do
      assert_text "Publish all saved draft changes?"
      click_button "Confirm"
    end
    assert_text "Website published. Visitors can now see this version."
    click_link "View live page"
    assert_no_text "Draft preview."
    assert_selector "h1", text: "Good teaching deserves a better workspace."
    assert_selector "h2", text: "Our learning approach"
  end

  test "public landing reflows on phones with visible keyboard focus" do
    @website.publish!(actor: admins(:one))
    visit landing_path
    assert_selector "h1", count: 1
    page.driver.browser.action.send_keys(:tab).perform
    assert_equal "Skip to content", page.evaluate_script("document.activeElement.textContent")
    assert_no_overflow
    assert_selector ".marketing-illustrated", count: 2
    assert_illustrations_loaded
    find(".marketing-image-left").execute_script("this.scrollIntoView({ block: 'center' })")
    page.save_screenshot(Rails.root.join("tmp/screenshots/website-illustrated-desktop.png"))
    page.save_screenshot(Rails.root.join("tmp/screenshots/website-desktop.png"))
    [ 390, 320 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: true)
      assert_no_overflow
      image_section = find(".marketing-image-left")
      image_section.execute_script("this.scrollIntoView({ block: 'center' })")
      copy_bottom = image_section.find(".marketing-copy").evaluate_script("this.getBoundingClientRect().bottom")
      image_top = image_section.find(".marketing-image").evaluate_script("this.getBoundingClientRect().top")
      assert_operator image_top, :>=, copy_bottom
      page.save_screenshot(Rails.root.join("tmp/screenshots/website-illustrated-#{width}.png"))
      click_button "Menu"
      assert_operator find_link("Sign in", exact: true).native.size.height, :>=, 44
      page.save_screenshot(Rails.root.join("tmp/screenshots/website-#{width}.png"))
      click_button "Menu"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private
    def assert_illustrations_loaded
      images = all(".marketing-image img", count: 2)
      images.each do |image|
        image.execute_script("this.scrollIntoView({ block: 'center' })")
        within image.find(:xpath, "..") do
          assert_selector("img") { |element| element.evaluate_script("this.complete && this.naturalWidth > 0") }
        end
      end
    end

    def assert_no_overflow
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    end
end
