require "test_helper"

class SupportMessageTest < ActiveSupport::TestCase
  setup do
    organization = organizations(:one)
    reporter = organization.memberships.create!(user: users(:two), status: "active")
    @ticket = SupportTicket.create!(
      organization: organization,
      reporter_membership: reporter,
      subject: "Attachment validation",
      category: "technical_issue",
      priority: "normal"
    )
    @message = @ticket.messages.build(author: reporter, body: "See attached files.")
  end

  test "accepts supported attachments" do
    @message.attachments.attach(io: StringIO.new("diagnostic details"), filename: "details.txt", content_type: "text/plain")

    assert_predicate @message, :valid?
  end

  test "rejects unsupported attachment types" do
    @message.attachments.attach(io: StringIO.new("audio"), filename: "recording.mp3", content_type: "audio/mpeg")

    assert_not @message.valid?
    assert_includes @message.errors[:attachments], "must be a PDF, office document, text file, or supported image"
  end

  test "rejects more than five attachments" do
    (SupportMessage::MAX_ATTACHMENTS + 1).times do |index|
      @message.attachments.attach(
        io: StringIO.new("file #{index}"), filename: "file-#{index}.txt", content_type: "text/plain"
      )
    end

    assert_not @message.valid?
    assert_includes @message.errors[:attachments], "cannot include more than 5 files"
  end

  test "rejects an attachment larger than twenty megabytes" do
    @message.attachments.attach(
      io: StringIO.new("pdf"), filename: "large.pdf", content_type: "application/pdf"
    )
    blob = @message.attachments.first.blob
    blob.define_singleton_method(:byte_size) { SupportMessage::MAX_ATTACHMENT_SIZE + 1 }

    assert_not @message.valid?
    assert_includes @message.errors[:attachments], "must each be 20 MB or smaller"
  end
end
