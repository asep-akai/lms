class AddIllustrationsToLandingSections < ActiveRecord::Migration[8.1]
  def up
    add_column :landing_sections, :illustration, :string
    add_column :landing_sections, :image_position, :string, default: "right", null: false

    execute <<~SQL
      UPDATE landing_sections
      SET illustration = 'course-materials'
      WHERE layout = 'story' AND heading = 'From the first class to the final certificate.';
    SQL
    execute <<~SQL
      UPDATE landing_sections
      SET illustration = 'review-feedback', image_position = 'left'
      WHERE layout = 'story' AND heading = 'Give feedback with more context.';
    SQL
  end

  def down
    remove_column :landing_sections, :image_position
    remove_column :landing_sections, :illustration
  end
end
