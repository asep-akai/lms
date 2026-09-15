require "test_helper"

class MaterialCompletionTest < ActiveSupport::TestCase
  test "requires the student to be enrolled in the material course" do
    membership = organizations(:one).memberships.create!(user: users(:two), status: "active")
    membership.role_ids = [ organizations(:one).roles.find_by!(key: "student").id ]
    course = organizations(:one).courses.create!(name: "Biology", description: "Living systems.")
    material = course.materials.new(title: "Cells")
    material.blocks.build(block_type: "text", body_html: "<p>Cell structure.</p>", position: 1)
    material.save!

    completion = MaterialCompletion.new(material: material, membership: membership, completed_at: Time.current)

    assert_not completion.valid?
    assert_includes completion.errors[:membership], "must be enrolled in this material's course"
  end
end
