require "test_helper"

class CourseContentTest < ActiveSupport::TestCase
  test "materials and quizzes share one course sequence" do
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    material = course.materials.new(title: "Cells")
    material.blocks.build(block_type: "text", body_html: "<p>Cell structures.</p>", position: 1)
    material.save!
    quiz = course.quizzes.create!(title: "Cells check-in")

    assert_equal [ material, quiz ], course.course_contents.reload.map(&:contentable)
    assert_equal [ 1, 2 ], course.course_contents.pluck(:position)
  end

  test "content must belong to the same course" do
    first_course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    second_course = organizations(:one).courses.create!(name: "Chemistry", description: "Matter and reactions.")
    quiz = first_course.quizzes.create!(title: "Cells check-in")

    content = CourseContent.new(course: second_course, contentable: quiz, position: 1)

    assert_not content.valid?
    assert_includes content.errors[:contentable], "must belong to the same course"
  end
end
