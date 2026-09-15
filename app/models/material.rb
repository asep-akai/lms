class Material < ApplicationRecord
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  MAX_IMAGE_SIZE = 10.megabytes

  belongs_to :course
  has_one :course_content, as: :contentable, dependent: :destroy, inverse_of: :contentable
  has_one_attached :cover_image
  has_many :blocks, -> { order(:position) }, class_name: "MaterialBlock", dependent: :destroy, inverse_of: :material
  has_many :material_completions, dependent: :destroy
  accepts_nested_attributes_for :blocks, allow_destroy: true
  attr_accessor :remove_cover_image

  delegate :organization, to: :course

  validates :title, presence: true, length: { maximum: 160 }
  validates :description, length: { maximum: 500 }
  validate :has_content
  validate :cover_image_is_supported
  after_create :append_to_course_contents
  after_save :remove_cover_image_if_requested

  private
    def append_to_course_contents
      CourseContent.append!(self)
    end

    def has_content
      errors.add(:blocks, "must include at least one text or image block") if blocks.reject(&:marked_for_destruction?).empty?
    end

    def cover_image_is_supported
      return unless cover_image.attached?

      errors.add(:cover_image, "must be JPEG, PNG, GIF, or WebP") unless cover_image.blob.content_type.in?(ALLOWED_IMAGE_TYPES)
      errors.add(:cover_image, "must be smaller than 10 MB") if cover_image.blob.byte_size > MAX_IMAGE_SIZE
    end

    def remove_cover_image_if_requested
      cover_image.purge if ActiveModel::Type::Boolean.new.cast(remove_cover_image)
    end
end
