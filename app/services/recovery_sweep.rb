class RecoverySweep
  def self.call!
    removed = 0

    RoleAssignment.includes(:role, :assignee).find_each do |assignment|
      valid_scope = case assignment.assignee
      when Admin
        assignment.role.global?
      when User
        assignment.role.organization.present? &&
          assignment.assignee.memberships.active.exists?(organization: assignment.role.organization)
      else
        false
      end

      if !valid_scope && assignment.destroy
        removed += 1
      end
    end

    removed
  end
end
