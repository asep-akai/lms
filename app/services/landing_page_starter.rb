class LandingPageStarter
  def self.call!
    LandingPage.find_or_create_by!(key: "home") do |page|
      content = default_content
      page.assign_attributes(page_attributes)
      section_attributes.each_with_index { |attributes, index| page.sections.build(attributes.merge(position: index)) }
      sections_by_anchor = content.fetch("sections").zip(page.sections.target).to_h { |section, record| [ "#section-#{section.fetch('id')}", record ] }

      { "header" => content.fetch("navigation", []), "footer" => content.dig("footer", "links") || [] }.each do |placement, links|
        links.each_with_index do |item, position|
          section = sections_by_anchor[item.fetch("url")]
          page.navigation_items.build(label: item.fetch("label"), placement: placement, position: position,
            landing_section: section, url: section ? nil : item.fetch("url"))
        end
      end
    end
  end

  def self.default_content
    JSON.parse(Rails.root.join("config/website_default.json").read)
  end

  def self.page_attributes
    content = default_content
    attributes = content.slice("site_name", "title", "description")
    if (footer = content["footer"])
      attributes.merge!("footer_text" => footer.fetch("text", ""), "footer_copyright" => footer.fetch("copyright", ""),
        "footer_background_style" => footer.fetch("background_style", "cream"), "footer_visible" => footer.fetch("visible", true),
        "footer_workspace_link" => footer.fetch("workspace_link", true))
    end
    attributes.symbolize_keys
  end

  def self.section_attributes
    default_content.fetch("sections").map do |section|
      section.slice(*LandingSection::CONTENT_FIELDS).except("id")
        .merge("background_style" => section.fetch("resolved_background_style")).symbolize_keys
    end
  end
end
