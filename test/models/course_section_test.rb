require "test_helper"

class CourseSectionTest < ActiveSupport::TestCase
  test "a new course starts with one default section" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")

    assert_equal 1, course.course_sections.count
    assert_equal "Course content", course.default_section.name
    assert_equal 1, course.default_section.position
  end

  test "a module can be assigned to a selected section when created" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    section = course.course_sections.create!(name: "Cell division", position: 2)
    material = course.materials.new(title: "Mitosis", course_section_id: section.id)
    material.blocks.build(block_type: "text", body_html: "<p>Mitosis.</p>", position: 1)

    material.save!

    assert_equal section, material.course_content.course_section
    assert_equal 1, material.course_content.position
  end
end
