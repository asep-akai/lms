class SupportMessage < ApplicationRecord
  ALLOWED_ATTACHMENT_TYPES = %w[
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/json
    text/plain
    text/csv
    image/jpeg
    image/png
    image/gif
    image/webp
  ].freeze
  MAX_ATTACHMENT_SIZE = 20.megabytes
  MAX_ATTACHMENTS = 5

  belongs_to :support_ticket, touch: true
  belongs_to :author, polymorphic: true
  has_many_attached :attachments

  validates :body, presence: true, length: { maximum: 10_000 }
  validate :author_can_participate
  validate :attachments_are_supported

  def author_name
    author.is_a?(Membership) ? author.user.name : author.name
  end

  private
    def author_can_participate
      return if author.is_a?(Admin)
      return if author.is_a?(Membership) && author.organization_id == support_ticket&.organization_id

      errors.add(:author, "must belong to the ticket organization")
    end

    def attachments_are_supported
      errors.add(:attachments, "cannot include more than #{MAX_ATTACHMENTS} files") if attachments.size > MAX_ATTACHMENTS
      attachments.each do |attachment|
        unless attachment.blob.content_type.in?(ALLOWED_ATTACHMENT_TYPES)
          errors.add(:attachments, "must be a PDF, office document, text file, or supported image")
        end
        if attachment.blob.byte_size > MAX_ATTACHMENT_SIZE
          errors.add(:attachments, "must each be 20 MB or smaller")
        end
      end
    end
end
