module Console
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[edit update toggle_status]

    def index
      authorize Organization
      @query = TableSearch.normalize(params[:query])
      organizations = TableSearch.call(
        policy_scope(Organization),
        query: @query,
        columns: %w[organizations.name organizations.slug organizations.status organizations.timezone]
      )
      @organizations = organizations.order(:name)
    end

    def new
      @organization = Organization.new(timezone: "Jakarta", locale: "en")
      authorize @organization
    end

    def create
      @organization = Organization.new(organization_params)
      authorize @organization
      owner = User.find_by(email: params.dig(:organization, :owner_email).to_s.downcase.strip)
      unless owner
        @organization.errors.add(:base, "Owner must be an existing user.")
        return render :new, status: :unprocessable_entity
      end

      OrganizationProvisioner.call!(organization: @organization, owner: owner)
      AuditRecorder.record!(action: "console.organization.created", auditable: @organization, organization: @organization)
      redirect_to console_organizations_path, notice: "Organization created."
    rescue ActiveRecord::RecordInvalid => error
      @organization.errors.add(:base, error.record.errors.full_messages.to_sentence)
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @organization
    end

    def update
      authorize @organization
      if @organization.update(organization_params)
        AuditRecorder.record!(
          action: "console.organization.updated",
          auditable: @organization,
          organization: @organization,
          changes: @organization.saved_changes.slice("name", "slug", "status", "timezone", "locale")
        )
        redirect_to console_organizations_path, notice: "Organization updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle_status
      authorize @organization, :update?
      reactivating = !@organization.active?
      new_status = reactivating ? "active" : "suspended"
      event = reactivating ? "reactivated" : "suspended"
      @organization.update!(status: new_status)
      AuditRecorder.record!(
        action: "console.organization.#{event}",
        auditable: @organization,
        organization: @organization,
        changes: @organization.saved_changes.slice("status")
      )
      redirect_to console_organizations_path, notice: "Organization #{event}."
    end

    private
      def set_organization
        @organization = Organization.find_by!(slug: params[:slug])
      end

      def organization_params
        params.require(:organization).permit(:name, :slug, :status, :timezone, :locale)
      end
  end
end
