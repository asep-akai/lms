class LandingNavigationItem < ApplicationRecord
  belongs_to :landing_page
  belongs_to :landing_section, optional: true

  validates :label, presence: true, length: { maximum: 60 }
  validates :placement, inclusion: { in: %w[header footer] }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :url, website_link: true, allow_blank: true, length: { maximum: 2000 }
  validate :one_destination

  def snapshot
    { "label" => label, "url" => landing_section_id ? "#section-#{landing_section_id}" : url }
  end

  def footer?
    placement == "footer"
  end

  def editor_anchor
    footer? ? "footer" : "navigation"
  end

  private
    def one_destination
      if landing_section_id.present? && !landing_section
        errors.add(:landing_section, "does not exist")
      elsif landing_section && landing_section.landing_page != landing_page
        errors.add(:landing_section, "must belong to this website")
      end
      if landing_section.nil? && url.blank?
        errors.add(:base, "Choose a page section or enter a destination URL.")
      elsif landing_section && url.present?
        errors.add(:base, "Choose either a page section or a URL, not both.")
      end
      errors.add(:url, "must use the section picker for links within this page") if url.to_s.start_with?("#")
    end
end
