class LandingSection < ApplicationRecord
  LAYOUTS = { "Hero" => "hero", "Story / introduction" => "story", "Features / benefits" => "features", "Planned features" => "roadmap", "Contact / call to action" => "contact" }.freeze
  IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  CONTENT_FIELDS = %w[id layout eyebrow heading body highlights button_label button_url image_alt illustration image_position background_style].freeze
  BACKGROUND_STYLES = { "Auto" => "auto", "Cream" => "cream", "Sage" => "sage", "Forest" => "forest" }.freeze
  ILLUSTRATIONS = {
    "course-materials" => { label: "Organized learning materials", asset: "marketing/course-materials-v1.jpg", alt: "Illustration of a chaptered lesson binder, reading materials and a video tablet." },
    "review-feedback" => { label: "Essay and audio feedback", asset: "marketing/review-feedback-v1.jpg", alt: "Illustration of headphones, an audio recording and a notebook annotated with feedback." }
  }.freeze

  belongs_to :landing_page
  has_many :navigation_items, class_name: "LandingNavigationItem", dependent: :destroy
  has_one_attached :image
  has_one_attached :brochure

  validates :layout, inclusion: { in: LAYOUTS.values }
  validates :background_style, inclusion: { in: BACKGROUND_STYLES.values }
  validates :illustration, inclusion: { in: ILLUSTRATIONS.keys }, allow_blank: true
  validates :image_position, inclusion: { in: %w[left right] }
  validates :heading, presence: true, length: { maximum: 160 }
  validates :eyebrow, :image_alt, length: { maximum: 160 }
  validates :body, length: { maximum: 5000 }
  validates :highlights, length: { maximum: 2000 }
  validates :button_label, length: { maximum: 60 }, presence: true, if: -> { button_url.present? }
  validates :button_url, presence: true, if: -> { button_label.present? }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :button_url, website_link: true, allow_blank: true
  validate :acceptable_files

  def snapshot
    attributes.slice(*CONTENT_FIELDS).merge("image" => image.attached? ? image.blob_id : nil,
      "brochure" => brochure.attached? ? brochure.blob_id : nil)
  end

  private
    def acceptable_files
      if image.attached?
        errors.add(:image, "must be a JPEG, PNG or WebP up to 5 MB") unless IMAGE_TYPES.include?(image.content_type) && image.byte_size <= 5.megabytes
        errors.add(:image_alt, "is required when an image is uploaded") if image_alt.blank?
      end
      if brochure.attached? && (brochure.content_type != "application/pdf" || brochure.byte_size > 10.megabytes)
        errors.add(:brochure, "must be a PDF up to 10 MB")
      end
    end
end
