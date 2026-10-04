require "test_helper"

class WebsiteAppearanceTest < ActionDispatch::IntegrationTest
  setup do
    @website = LandingPageStarter.call!
    sign_in admins(:one), scope: :admin
  end

  test "background selection validates and is frozen when published" do
    section = @website.sections.second
    get edit_console_website_section_path(section)
    assert_select "select[name='landing_section[background_style]'] option", count: 4
    patch console_website_section_path(section), params: { landing_section: { background_style: "forest" } }
    assert_redirected_to console_website_path
    assert_equal "forest", section.reload.background_style
    get preview_console_website_path
    assert_select "#section-#{section.id}.marketing-theme-forest"
    @website.publish!(actor: admins(:one))
    snapshot = @website.current_publication.content.deep_dup
    patch console_website_section_path(section), params: { landing_section: { background_style: "sage" } }
    get landing_path
    assert_select "#section-#{section.id}.marketing-theme-forest"
    get preview_console_website_path
    assert_select "#section-#{section.id}.marketing-theme-sage"
    assert_equal snapshot, @website.current_publication.reload.content
    patch console_website_section_path(section), params: { landing_section: { background_style: "forest injected-class" } }
    assert_response :unprocessable_entity
    assert_equal "sage", section.reload.background_style
    assert_select "h1", "Edit website section"
  end

  test "auto recalculates only visible draft sections after hiding and reordering" do
    @website.sections.each { |section| section.update!(background_style: "auto") }
    hero, story, features = @website.sections.first(3)
    @website.publish!(actor: admins(:one))
    patch console_website_section_path(hero), params: { landing_section: { visible: "0" } }
    get preview_console_website_path
    assert_select "#section-#{story.id}.marketing-theme-cream"
    patch move_console_website_section_path(features), params: { direction: "up" }
    get preview_console_website_path
    assert_select "main section:first-of-type.marketing-theme-forest"
    get landing_path
    assert_select "#section-#{story.id}.marketing-theme-sage"
    assert_select "#section-#{hero.id}.marketing-theme-cream"
  end

  test "old publications retain layout colors rather than inheriting draft themes" do
    content = @website.draft_content
    content.fetch("sections").each { |section| section.except!("background_style", "resolved_background_style") }
    @website.update!(current_publication: @website.publications.create!(content: content))
    @website.sections.first.update!(background_style: "forest")
    get landing_path
    assert_select "section[class*='marketing-theme-']", count: 0
    assert_select "section.marketing-features", count: 1
  end

  test "editor shows illustration uploaded image and text only states" do
    section = @website.sections.find_by!(illustration: "course-materials")
    get edit_console_website_section_path(section)
    assert_select ".website-image-preview img[src*='course-materials-v1']"
    assert_select ".website-image-preview", text: /Built-in illustration: Organized learning materials/
    section.update!(image_alt: "Our classroom")
    section.image.attach(io: StringIO.new("image-data"), filename: "classroom.png", content_type: "image/png")
    get edit_console_website_section_path(section)
    assert_select ".website-image-preview img[src='#{asset_console_website_path(section.image.blob_id)}'][alt='Our classroom']"
    assert_select ".website-image-preview", text: /Uploaded image: classroom.png/
    get asset_console_website_path(section.image.blob_id)
    assert_response :success
    patch console_website_section_path(section), params: { landing_section: { illustration: "" }, remove_image: "1" }
    get edit_console_website_section_path(section)
    assert_select ".website-image-preview img[hidden]"
    assert_select ".website-image-preview", text: /No image selected/
  end
end
