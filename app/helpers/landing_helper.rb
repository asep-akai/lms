module LandingHelper
  def marketing_footer
    @content&.fetch("footer", nil) || { "text" => "Learning, organized.", "copyright" => "", "background_style" => nil,
      "visible" => true, "workspace_link" => true, "links" => [] }
  end

  def marketing_section_theme(section)
    style = section["resolved_background_style"]
    "marketing-theme-#{style}" if LandingSectionBackgrounds::STYLES.include?(style)
  end

  def website_illustration_previews
    LandingSection::ILLUSTRATIONS.transform_values do |item|
      { src: image_path(item.fetch(:asset)), alt: item.fetch(:alt), label: "Built-in illustration: #{item.fetch(:label)}" }
    end
  end

  def website_uploaded_preview(section)
    return {} unless section.image.attached? && section.image.persisted?

    { src: asset_console_website_path(section.image.blob_id), alt: section.image_alt,
      label: "Uploaded image: #{section.image.filename}" }
  end

  def marketing_workspace_path
    admin_signed_in? ? console_root_path : user_root_path
  end

  def marketing_workspace_label
    return "Open console" if admin_signed_in?

    user_signed_in? ? "Open workspace" : "Sign in"
  end

  def marketing_section_image(section)
    if section["image"]
      { src: marketing_asset_path(section["image"]), alt: section["image_alt"] }
    elsif (illustration = LandingSection::ILLUSTRATIONS[section["illustration"]])
      { src: illustration.fetch(:asset), alt: section["image_alt"].presence || illustration.fetch(:alt), width: 1536, height: 1024 }
    end
  end

  def marketing_navigation
    return [] unless @content
    return @content.fetch("navigation") if @content.key?("navigation")

    @content.fetch("sections", []).any? { |section| section["layout"] == "features" } ? [ { "label" => "The platform", "url" => "#platform" } ] : []
  end

  def marketing_asset_path(blob_id)
    @preview ? asset_console_website_path(blob_id) : landing_asset_path(blob_id)
  end

  def marketing_section_anchor(section)
    "section-#{section.fetch('id')}"
  end

  def marketing_paragraphs(text)
    safe_join(text.to_s.split(/\n\s*\n/).map { |paragraph| tag.p(paragraph) })
  end
end
