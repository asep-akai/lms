class CreateCourseContents < ActiveRecord::Migration[8.1]
  def up
    create_table :course_contents do |t|
      t.references :course, null: false, foreign_key: true
      t.references :contentable, polymorphic: true, null: false
      t.integer :position, null: false

      t.timestamps
    end
    add_index :course_contents, %i[course_id position]
    add_index :course_contents, %i[contentable_type contentable_id], unique: true

    execute <<~SQL.squish
      INSERT INTO course_contents
        (course_id, contentable_type, contentable_id, position, created_at, updated_at)
      SELECT
        course_id,
        contentable_type,
        contentable_id,
        ROW_NUMBER() OVER (
          PARTITION BY course_id
          ORDER BY content_created_at, contentable_type, contentable_id
        ),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM (
        SELECT course_id, 'Material' AS contentable_type, id AS contentable_id, created_at AS content_created_at
        FROM materials
        UNION ALL
        SELECT course_id, 'Quiz' AS contentable_type, id AS contentable_id, created_at AS content_created_at
        FROM quizzes
      ) existing_contents
    SQL

    execute <<~SQL.squish
      INSERT INTO permissions (key, name, description, created_at, updated_at)
      VALUES (
        'course_contents.update',
        'Arrange course content',
        'Change the order of materials and quizzes in a course.',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
      ON CONFLICT (key) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        updated_at = CURRENT_TIMESTAMP
    SQL

    execute <<~SQL.squish
      INSERT INTO role_permissions (role_id, permission_id, created_at, updated_at)
      SELECT roles.id, permissions.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM roles
      CROSS JOIN permissions
      WHERE roles.organization_id IS NOT NULL
        AND roles.key = 'admin'
        AND permissions.key = 'course_contents.update'
      ON CONFLICT (role_id, permission_id) DO NOTHING
    SQL
  end

  def down
    execute <<~SQL.squish
      DELETE FROM role_permissions
      WHERE permission_id IN (
        SELECT id FROM permissions WHERE key = 'course_contents.update'
      )
    SQL
    execute "DELETE FROM permissions WHERE key = 'course_contents.update'"
    drop_table :course_contents
  end
end
