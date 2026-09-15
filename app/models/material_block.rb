class MaterialBlock < ApplicationRecord
  TYPES = %w[text image].freeze
  ALLOWED_HTML_TAGS = %w[p h2 h3 br strong b em i u ul ol li span].freeze
  ALLOWED_HTML_ATTRIBUTES = %w[style].freeze
  ALLOWED_TEXT_COLORS = {
    "#0f172a" => "rgb(15,23,42)",
    "#b91c1c" => "rgb(185,28,28)",
    "#1d4ed8" => "rgb(29,78,216)",
    "#15803d" => "rgb(21,128,61)"
  }.freeze

  belongs_to :material, inverse_of: :blocks
  has_one_attached :image

  validates :block_type, inclusion: { in: TYPES }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
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

    def sanitize_body_html
      fragment = Nokogiri::HTML5.fragment(body_html)
      fragment.css("[style]").each { |node| constrain_text_color(node) }
      self.body_html = ActionController::Base.helpers.sanitize(
        fragment.to_html,
        tags: ALLOWED_HTML_TAGS,
        attributes: ALLOWED_HTML_ATTRIBUTES
      )
    end

    def constrain_text_color(node)
      declaration = node["style"].downcase.delete(" ")
      color = declaration[/(?:\A|;)color:(#[0-9a-f]{6}|rgb\(\d+,\d+,\d+\))(?:;|\z)/, 1]
      canonical = ALLOWED_TEXT_COLORS.find { |hex, rgb| color.in?([ hex, rgb ]) }&.first

      canonical ? node["style"] = "color: #{canonical};" : node.remove_attribute("style")
    end

    def image_is_attached
      errors.add(:image, "must be selected") if image? && !image.attached?
    end

    def image_is_supported
      return unless image? && image.attached?

      errors.add(:image, "must be JPEG, PNG, GIF, or WebP") unless image.blob.content_type.in?(Material::ALLOWED_IMAGE_TYPES)
      errors.add(:image, "must be smaller than 10 MB") if image.blob.byte_size > Material::MAX_IMAGE_SIZE
    end
end
