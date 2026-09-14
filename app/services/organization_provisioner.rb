class OrganizationProvisioner
  DEFAULT_ROLES = {
    "admin" => "Organization administrator",
    "teacher" => "Teacher",
    "student" => "Student"
  }.freeze

  def self.call!(organization:, owner:)
    Organization.transaction do
      organization.save!

      RbacSeeder.call!

      roles = DEFAULT_ROLES.to_h do |key, name|
        [ key, organization.roles.create!(key: key, name: name, system: true) ]
      end
      roles.fetch("admin").permissions = Permission.organization_assignable

      membership = organization.memberships.create!(user: owner)
      membership.role_ids = [ roles.fetch("admin").id ]

      AuditRecorder.record!(
        action: "organization.created",
        auditable: organization,
        organization: organization,
        actor: owner,
        metadata: { name: organization.name, slug: organization.slug }
      )

      organization
    end
  end
end
