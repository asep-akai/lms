class LandingPage < ApplicationRecord
  has_many :sections, -> { order(:position, :id) }, class_name: "LandingSection", dependent: :destroy
  has_many :navigation_items, -> { order(:position, :id) }, class_name: "LandingNavigationItem", dependent: :destroy
  has_many :publications, class_name: "LandingPublication", dependent: :restrict_with_error
  belongs_to :current_publication, class_name: "LandingPublication", optional: true
  has_one_attached :social_image

  validates :key, inclusion: { in: [ "home" ] }, uniqueness: true
  validates :site_name, :title, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 320 }
  validates :footer_text, length: { maximum: 500 }
  validates :footer_copyright, length: { maximum: 200 }
  validates :footer_background_style, inclusion: { in: LandingSectionBackgrounds::STYLES }
  validates :footer_visible, :footer_workspace_link, inclusion: { in: [ true, false ] }
  normalizes :footer_text, :footer_copyright, with: ->(value) { value.to_s }, apply_to_nil: true
  validate :acceptable_social_image

  def default_template?
    current_publication_id.nil? && !publications.exists?
  end

  def draft_content
    attributes.slice("site_name", "title", "description").merge(
      "sections" => LandingSectionBackgrounds.resolve(sections.where(visible: true).map(&:snapshot)),
      "navigation" => navigation_snapshot("header"),
      "footer" => { "text" => footer_text, "copyright" => footer_copyright, "background_style" => footer_background_style,
        "visible" => footer_visible, "workspace_link" => footer_workspace_link, "links" => navigation_snapshot("footer") },
      "social_image" => social_image.attached? ? social_image.blob_id : nil
    )
  end

  def publish!(actor:)
    with_lock do
      visible_sections = sections.where(visible: true).to_a
      errors.add(:base, "Add a visible hero section in the first position before publishing.") unless visible_sections.first&.layout == "hero"
      errors.add(:base, "Keep exactly one visible hero section.") unless visible_sections.count { |section| section.layout == "hero" } == 1
      raise ActiveRecord::RecordInvalid, self if errors.any?

      publication = publications.create!(content: draft_content)
      blobs = visible_sections.flat_map { |section| [ section.image, section.brochure ].select(&:attached?).map(&:blob) }
      blobs << social_image.blob if social_image.attached?
      publication.assets.attach(blobs.uniq)
      update!(current_publication: publication)
      AuditRecorder.record!(action: "website.published", auditable: self, organization: nil, actor: actor,
        metadata: { publication_id: publication.id, sections: visible_sections.size })
    end
  end

  private
    def navigation_snapshot(placement)
      navigation_items.where(placement: placement).includes(:landing_section)
        .select { |item| item.visible? && (!item.landing_section || item.landing_section.visible?) }.map(&:snapshot)
    end

    def acceptable_social_image
      return unless social_image.attached?

      errors.add(:social_image, "must be a JPEG, PNG or WebP up to 5 MB") unless LandingSection::IMAGE_TYPES.include?(social_image.content_type) && social_image.byte_size <= 5.megabytes
    end
end
