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
    "roles.index" => [ "List roles", "View roles and their permissions." ],
    "roles.create" => [ "Create roles", "Create custom roles." ],
    "roles.update" => [ "Update roles", "Update custom roles and permissions." ],
    "roles.destroy" => [ "Delete roles", "Delete unused custom roles." ],
    "organization.update" => [ "Update organization", "Update organization settings." ],
    "memberships.index" => [ "List members", "View organization members." ],
    "memberships.create" => [ "Add members", "Invite members to an organization." ],
    "memberships.update" => [ "Update members", "Update member status and role assignments." ],
    "memberships.destroy" => [ "Remove members", "Remove members from an organization." ],
    "audit_events.index" => [ "View audit log", "Review organization security and administrative activity." ]
  }.freeze

  has_many :role_permissions, dependent: :restrict_with_error
  has_many :roles, through: :role_permissions

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
