class QuizPageBlock < ApplicationRecord
  TYPES = %w[text image].freeze
  ALLOWED_HTML_TAGS = MaterialBlock::ALLOWED_HTML_TAGS
  ALLOWED_HTML_ATTRIBUTES = [].freeze

  belongs_to :quiz_page, inverse_of: :blocks
  has_one_attached :image

  validates :block_type, inclusion: { in: TYPES }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :body_html, length: { maximum: 50_000 }, if: :text?
  validate :text_has_content
  validate :image_is_attached
  validate :image_is_supported
  before_validation :sanitize_body_html, if: :text?

  def text? = block_type == "text"
  def image? = block_type == "image"

  private
    def text_has_content
      return unless text?
      return if ActionView::Base.full_sanitizer.sanitize(body_html).squish.present?

      errors.add(:body_html, "must include text")
    end

    def image_is_attached
      errors.add(:image, "must be selected") if image? && !image.attached?
    end

    def image_is_supported
      return unless image? && image.attached?

      errors.add(:image, "must be JPEG, PNG, GIF, or WebP") unless image.blob.content_type.in?(Material::ALLOWED_IMAGE_TYPES)
      errors.add(:image, "must be smaller than 10 MB") if image.blob.byte_size > Material::MAX_IMAGE_SIZE
    end

    def sanitize_body_html
      self.body_html = ActionController::Base.helpers.sanitize(
        body_html,
        tags: ALLOWED_HTML_TAGS,
        attributes: ALLOWED_HTML_ATTRIBUTES
      )
    end
end
