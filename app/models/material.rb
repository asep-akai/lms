class Material < ApplicationRecord
  ALLOWED_HTML_TAGS = %w[p br strong b em i u ul ol li].freeze
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  MAX_IMAGE_SIZE = 10.megabytes

  belongs_to :course
  has_many_attached :images

  delegate :organization, to: :course

  validates :title, presence: true, length: { maximum: 160 }
  validates :body_html, presence: true, length: { maximum: 50_000 }
  validate :body_has_text
  validate :images_are_supported

  private
    def body_has_text
      return if ActionView::Base.full_sanitizer.sanitize(body_html).squish.present?

      errors.add(:body_html, "must include text")
    end

    def images_are_supported
      images.each do |image|
        errors.add(:images, "must be JPEG, PNG, GIF, or WebP") unless image.blob.content_type.in?(ALLOWED_IMAGE_TYPES)
        errors.add(:images, "must be smaller than 10 MB") if image.blob.byte_size > MAX_IMAGE_SIZE
      end
    end
end
