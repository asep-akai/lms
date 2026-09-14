class DashboardController < AppController
  def index
    authorize :dashboard, :show?
    @organizations = policy_scope(Organization).order(:name).to_a

    redirect_to @organizations.first and return if @organizations.one?

    organization_ids = @organizations.map(&:id)
    @roles_by_organization_id = current_user.roles.where(organization_id: organization_ids).ordered.group_by(&:organization_id)
  end
end
