require "test_helper"

class LandingPageStarterTest < ActiveSupport::TestCase
  test "captured default is portable and does not use local uploaded assets" do
    content = LandingPageStarter.default_content
    assert_nil content["social_image"]
    assert_equal %w[cream sage forest cream sage forest], content.fetch("sections").map { |section| section.fetch("resolved_background_style") }
    content.fetch("sections").each_with_index do |section, index|
      assert_equal "starter-#{index + 1}", section.fetch("id")
      assert_nil section["image"]
      assert_nil section["brochure"]
      next unless section["illustration"]

      illustration = LandingSection::ILLUSTRATIONS.fetch(section.fetch("illustration"))
      assert Rails.root.join("app/assets/images", illustration.fetch(:asset)).file?
    end
    anchors = content.fetch("sections").map { |section| "#section-#{section.fetch('id')}" }
    content.fetch("navigation").each { |item| assert_includes anchors, item.fetch("url") }
    content["title"] = "Modified in memory"
    assert_equal "Kelasona | Learning, organized.", LandingPageStarter.default_content.fetch("title")
  end

  test "fresh editable draft copies captured content and remaps navigation to actual section records" do
    page = LandingPageStarter.call!
    content = LandingPageStarter.default_content
    assert_equal content.fetch("title"), page.title
    assert_equal content.fetch("sections").map { |section| section.fetch("heading") }, page.sections.map(&:heading)
    assert_equal content.fetch("sections").map { |section| section.fetch("resolved_background_style") }, page.sections.map(&:background_style)
    assert_equal [ "course-materials", "review-feedback" ], page.sections.filter_map(&:illustration)
    assert_equal page.sections.third, page.navigation_items.first.landing_section
    assert_nil page.navigation_items.first.url
    assert_equal "#section-#{page.sections.third.id}", page.draft_content.fetch("navigation").first.fetch("url")
    assert_nil page.current_publication
    assert_empty page.publications
  end

  test "existing drafts publications and intentionally unpublished pages are never replaced" do
    page = LandingPageStarter.call!
    page.update!(footer_text: "Custom footer", title: "Custom site")
    page.sections.first.update!(heading: "Custom headline", background_style: "sage")
    page.navigation_items.first.update!(label: "Custom label")
    page.publish!(actor: admins(:one))
    publication = page.current_publication
    draft = page.draft_content
    published = publication.content
    assert_no_difference [ "LandingSection.count", "LandingNavigationItem.count", "LandingPublication.count" ] do
      LandingPageStarter.call!
    end
    assert_equal draft, page.reload.draft_content
    assert_equal publication, page.current_publication
    assert_equal published, publication.reload.content
    page.update!(current_publication: nil)
    LandingPageStarter.call!
    assert_nil page.reload.current_publication
    assert_not page.default_template?
    assert_equal draft, page.draft_content
  end
end
