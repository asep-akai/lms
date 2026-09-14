require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  test "accepts supported image attachments" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    material = course.materials.new(title: "Cells", body_html: "<p>Cell structures.</p>")
    material.images.attach(io: StringIO.new("image data"), filename: "cell.png", content_type: "image/png")

    assert material.valid?
    assert material.save
    assert_equal "cell.png", material.images.first.filename.to_s
  end

  test "rejects unsupported attachments" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    material = course.materials.new(title: "Cells", body_html: "<p>Cell structures.</p>")
    material.images.attach(io: StringIO.new("document"), filename: "notes.txt", content_type: "text/plain")

    assert_not material.valid?
    assert_includes material.errors[:images], "must be JPEG, PNG, GIF, or WebP"
  end
end
