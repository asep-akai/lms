require "test_helper"

class LandingSectionBackgroundsTest < ActiveSupport::TestCase
  test "starter defaults have distinct neighboring backgrounds" do
    assert_equal %w[cream sage forest cream sage forest], LandingPageStarter.default_content.fetch("sections").map { |section| section.fetch("resolved_background_style") }
  end

  test "automatic choices avoid previous resolved and next explicit colors without changing the inputs" do
    sections = [
      { "layout" => "story", "background_style" => "cream" },
      { "layout" => "story", "background_style" => "auto" },
      { "layout" => "story", "background_style" => "sage" },
      { "layout" => "story", "background_style" => "sage" },
      { "layout" => "story" },
      { "layout" => "story" }
    ]
    original = sections.deep_dup
    assert_equal %w[cream forest sage sage cream sage], LandingSectionBackgrounds.resolve(sections).map { |section| section.fetch("resolved_background_style") }
    assert_equal original, sections
    assert_empty LandingSectionBackgrounds.resolve([])
  end
end
