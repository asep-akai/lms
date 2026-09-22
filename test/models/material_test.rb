require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  test "accepts supported image attachments" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    material = course.materials.new(title: "Cells")
    material.blocks.build(block_type: "text", body_html: "<p>Cell structures.</p>", position: 1)
    image_block = material.blocks.build(block_type: "image", position: 2)
    image_block.image.attach(io: StringIO.new("image data"), filename: "cell.png", content_type: "image/png")

    assert material.valid?
    assert material.save
    assert_equal %w[text image], material.blocks.pluck(:block_type)
    assert_equal "cell.png", material.blocks.second.image.filename.to_s
  end

  test "rejects unsupported attachments" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    material = course.materials.new(title: "Cells")
    image_block = material.blocks.build(block_type: "image", position: 1)
    image_block.image.attach(io: StringIO.new("document"), filename: "notes.txt", content_type: "text/plain")

    assert_not material.valid?
    assert_includes image_block.errors[:image], "must be JPEG, PNG, GIF, or WebP"
  end

  test "requires at least one content block" do
    material = organizations(:one).courses.create!(name: "Biology", description: "Living systems.").materials.new(title: "Cells")

    assert_not material.valid?
    assert_includes material.errors[:blocks], "must include at least one text, image, or video block"
  end

  test "accepts supported YouTube links and derives a privacy enhanced embed URL" do
    material = organizations(:one).courses.create!(name: "Video course", description: "Video lessons.").materials.new(title: "Video lesson")
    block = material.blocks.build(block_type: "video", position: 1, video_url: "https://youtu.be/dQw4w9WgXcQ?t=10")

    assert block.valid?
    assert_equal "dQw4w9WgXcQ", block.youtube_video_id
    assert_equal "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ", block.youtube_embed_url
  end

  test "rejects video links from unsupported hosts" do
    material = organizations(:one).courses.create!(name: "Video course", description: "Video lessons.").materials.new(title: "Video lesson")
    block = material.blocks.build(block_type: "video", position: 1, video_url: "https://example.com/watch?v=dQw4w9WgXcQ")

    assert_not block.valid?
    assert_includes block.errors[:video_url], "must be a valid YouTube link"
  end

  test "keeps supported article formatting and removes arbitrary styles" do
    block = MaterialBlock.new(
      material: organizations(:one).courses.create!(name: "Biology", description: "Living systems.").materials.new(title: "Cells"),
      block_type: "text",
      position: 1,
      body_html: '<h2 style="color: rgb(185, 28, 28); font-size: 90px">Cell structure</h2><p style="color: hotpink">Details</p>'
    )

    assert block.valid?
    assert_equal '<h2 style="color:#b91c1c;">Cell structure</h2><p>Details</p>', block.body_html
  end

  test "keeps the optional cover image separate from article images" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    material = course.materials.new(title: "Cells")
    material.blocks.build(block_type: "text", body_html: "<p>Cell structures.</p>", position: 1)
    material.cover_image.attach(io: StringIO.new("cover data"), filename: "cover.png", content_type: "image/png")

    assert material.save
    assert_equal "cover.png", material.cover_image.filename.to_s
    assert_empty material.blocks.select(&:image?)
  end
end
