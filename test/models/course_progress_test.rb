require "test_helper"

class CourseProgressTest < ActiveSupport::TestCase
  test "counts finished materials and submitted quizzes as completed modules" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    course.course_enrollments.create!(membership: membership)
    material = course.materials.new(title: "Cells")
    material.blocks.build(block_type: "text", body_html: "<p>Cell structure.</p>", position: 1)
    material.save!
    quiz = course.quizzes.create!(title: "Cells check-in")

    progress = CourseProgress.for(courses: [ course ], memberships: [ membership ]).fetch([ course.id, membership.id ])
    assert_equal 0, progress.completed_modules
    assert_equal 2, progress.total_modules
    assert_equal 0, progress.percentage

    membership.material_completions.create!(material: material, completed_at: Time.current)
    QuizAttempt.create!(quiz: quiz, membership: membership, started_at: Time.current, last_activity_at: Time.current, submitted_at: Time.current)

    progress = CourseProgress.for(courses: [ course ], memberships: [ membership ]).fetch([ course.id, membership.id ])
    assert_equal 2, progress.completed_modules
    assert_equal 100, progress.percentage
  end

  test "an empty course remains at zero percent" do
    membership = memberships(:one)
    course = organizations(:one).courses.create!(name: "Empty course", description: "Content is coming soon.")

    progress = CourseProgress.for(courses: [ course ], memberships: [ membership ]).fetch([ course.id, membership.id ])

    assert_equal 0, progress.total_modules
    assert_equal 0, progress.percentage
  end
end
