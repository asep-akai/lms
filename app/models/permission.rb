class Permission < ApplicationRecord
  CATALOG = {
    "console.access" => [ "Access console", "Sign in to the platform console." ],
    "organizations.index" => [ "List organizations", "View organizations in the platform console." ],
    "organizations.create" => [ "Create organizations", "Provision organizations and their default roles." ],
    "organizations.update" => [ "Update organizations", "Update or suspend organizations from the console." ],
    "users.index" => [ "List users", "View application users in the console." ],
    "users.create" => [ "Create users", "Create application user accounts." ],
    "users.update" => [ "Update users", "Update or suspend application users." ],
    "users.destroy" => [ "Delete users", "Remove application user accounts." ],
    "admins.index" => [ "List administrators", "View platform administrators." ],
    "admins.create" => [ "Create administrators", "Create platform administrator accounts." ],
    "admins.update" => [ "Update administrators", "Update or suspend platform administrators." ],
    "admins.destroy" => [ "Delete administrators", "Remove platform administrator accounts." ],
    "support_tickets.console" => [ "Manage escalated support", "View and respond to support tickets escalated by organizations." ],
    "roles.index" => [ "List roles", "View roles and their permissions." ],
    "roles.create" => [ "Create roles", "Create custom roles." ],
    "roles.update" => [ "Update roles", "Update custom roles and permissions." ],
    "roles.destroy" => [ "Delete roles", "Delete unused custom roles." ],
    "organization.update" => [ "Update organization", "Update organization settings." ],
    "memberships.index" => [ "List members", "View organization members." ],
    "memberships.create" => [ "Add members", "Invite members to an organization." ],
    "memberships.update" => [ "Update members", "Update member status and role assignments." ],
    "memberships.destroy" => [ "Remove members", "Remove members from an organization." ],
    "students.index" => [ "List students", "View students and their course completion summaries." ],
    "students.show" => [ "View student progress", "Inspect a student's course and module completion." ],
    "courses.index" => [ "List courses", "View every course in the organization." ],
    "courses.create" => [ "Create courses", "Create courses in the organization." ],
    "courses.update" => [ "Update courses", "Update course names and descriptions." ],
    "courses.destroy" => [ "Delete courses", "Delete courses and their enrollments." ],
    "course_enrollments.update" => [ "Manage course enrollments", "Enroll or remove students from courses." ],
    "course_contents.update" => [ "Arrange course content", "Change the order of materials and quizzes in a course." ],
    "class_meetings.index" => [ "List all class meetings", "View every scheduled class meeting in the organization." ],
    "class_meetings.create" => [ "Schedule class meetings", "Schedule meetings and notify assigned teachers and students." ],
    "class_meetings.update" => [ "Update class meetings", "Change scheduled meeting details and assignments." ],
    "class_meetings.destroy" => [ "Delete class meetings", "Delete scheduled class meetings." ],
    "class_meeting_feedbacks.index" => [ "View class feedback", "Review teacher and student feedback for organization classes." ],
    "certificates.index" => [ "View all certificates", "View certificates issued to students in the organization." ],
    "certificates.create" => [ "Generate certificates", "Generate certificates from published assessment results." ],
    "assignments.index" => [ "List assignments", "View assignments in the organization." ],
    "assignments.create" => [ "Create assignments", "Assign work and documents to students." ],
    "assignments.review" => [ "Review assignments", "View submissions and send teacher comments." ],
    "materials.index" => [ "List materials", "View materials in organization courses." ],
    "materials.create" => [ "Create materials", "Create text and image materials in organization courses." ],
    "materials.update" => [ "Update materials", "Edit course materials and their images." ],
    "materials.destroy" => [ "Delete materials", "Delete course materials and their images." ],
    "quizzes.index" => [ "List quizzes", "View quizzes in organization courses." ],
    "quizzes.create" => [ "Create quizzes", "Create quizzes and questions in organization courses." ],
    "quizzes.update" => [ "Update quizzes", "Edit quizzes and their questions." ],
    "quizzes.destroy" => [ "Delete quizzes", "Delete quizzes and their questions." ],
    "quiz_attempts.index" => [ "List quiz attempts", "View student attempt statuses for quizzes." ],
    "quiz_attempts.show" => [ "View quiz attempts", "Review a student's answers for a quiz." ],
    "quiz_attempts.review" => [ "Review quiz attempts", "Grade attempts, save feedback, and publish results." ],
    "quiz_attempts.ai_analyze" => [ "Analyze quiz attempts with AI", "Generate draft performance analysis with the configured AI provider." ],
    "quiz_attempts.reset" => [ "Reset quiz attempts", "Delete a student's attempt and allow them to retry the quiz." ],
    "audit_events.index" => [ "View audit log", "Review organization security and administrative activity." ],
    "support_tickets.manage" => [ "Manage support tickets", "View, respond to, and escalate support tickets in the organization." ]
  }.freeze

  CONSOLE_ONLY_KEYS = %w[
    console.access
    organizations.index organizations.create organizations.update
    users.index users.create users.update users.destroy
    admins.index admins.create admins.update admins.destroy
    support_tickets.console
  ].freeze

  ORGANIZATION_ONLY_KEYS = %w[
    organization.update
    memberships.index memberships.create memberships.update memberships.destroy
    students.index students.show
    courses.index courses.create courses.update courses.destroy
    course_enrollments.update course_contents.update
    class_meetings.index class_meetings.create class_meetings.update class_meetings.destroy class_meeting_feedbacks.index
    certificates.index certificates.create
    assignments.index assignments.create assignments.review
    materials.index materials.create materials.update materials.destroy
    quizzes.index quizzes.create quizzes.update quizzes.destroy
    quiz_attempts.index quiz_attempts.show quiz_attempts.review quiz_attempts.ai_analyze quiz_attempts.reset
    audit_events.index
    support_tickets.manage
  ].freeze

  ORGANIZATION_GROUPS = {
    "Organization" => %w[organization.update],
    "Members" => %w[memberships.index memberships.create memberships.update memberships.destroy],
    "Students" => %w[students.index students.show],
    "Courses" => %w[courses.index courses.create courses.update courses.destroy course_enrollments.update course_contents.update materials.index materials.create materials.update materials.destroy quizzes.index quizzes.create quizzes.update quizzes.destroy quiz_attempts.index quiz_attempts.show quiz_attempts.review quiz_attempts.ai_analyze quiz_attempts.reset],
    "Classes" => %w[class_meetings.index class_meetings.create class_meetings.update class_meetings.destroy class_meeting_feedbacks.index],
    "Certificates" => %w[certificates.index certificates.create],
    "Assignments" => %w[assignments.index assignments.create assignments.review],
    "Roles" => %w[roles.index roles.create roles.update roles.destroy],
    "Audit" => %w[audit_events.index],
    "Support" => %w[support_tickets.manage]
  }.freeze

  CONSOLE_GROUPS = {
    "Console access" => %w[console.access],
    "Organizations" => %w[organizations.index organizations.create organizations.update],
    "Users" => %w[users.index users.create users.update users.destroy],
    "Administrators" => %w[admins.index admins.create admins.update admins.destroy],
    "Support" => %w[support_tickets.console],
    "Roles" => %w[roles.index roles.create roles.update roles.destroy]
  }.freeze

  has_many :role_permissions, dependent: :restrict_with_error
  has_many :roles, through: :role_permissions

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :ordered, -> { order(:name) }
  scope :organization_assignable, -> { where.not(key: CONSOLE_ONLY_KEYS) }
  scope :console_assignable, -> { where.not(key: ORGANIZATION_ONLY_KEYS) }

  def self.organization_groups
    grouped(ORGANIZATION_GROUPS)
  end

  def self.console_groups
    grouped(CONSOLE_GROUPS)
  end

  def self.grouped(definitions)
    permissions_by_key = where(key: definitions.values.flatten).index_by(&:key)
    definitions.map do |label, keys|
      [ label, keys.filter_map { |key| permissions_by_key[key] } ]
    end
  end

  private_class_method :grouped
end
