class OrganizationsController < AppController
  before_action :set_organization, only: %i[show edit update]

  def index
    authorize Organization
    @organizations = policy_scope(Organization).order(:name)
  end

  def show
    authorize @organization
    @roles = Current.membership.roles.ordered
  end

  def edit
    authorize @organization
  end

  def update
    authorize @organization
    if @organization.update(organization_params)
      AuditRecorder.record!(
        action: "organization.updated",
        auditable: @organization,
        organization: @organization,
        changes: @organization.saved_changes.slice("name", "slug", "timezone", "locale")
      )
      redirect_to @organization, notice: "Organization updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_organization
      @organization = Organization.find_by!(slug: params[:slug])
      Current.organization = @organization
      Current.membership = current_user.memberships.active.find_by(organization: @organization)
    end

    def organization_params
      params.require(:organization).permit(:name, :slug, :timezone, :locale)
    end
end
