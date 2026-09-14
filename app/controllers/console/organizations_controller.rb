module Console
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[edit update destroy]

    def index
      authorize Organization
      @organizations = policy_scope(Organization).order(:name)
    end

    def new
      @organization = Organization.new(timezone: "UTC", locale: "en")
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
        AuditRecorder.record!(action: "console.organization.updated", auditable: @organization, organization: @organization)
        redirect_to console_organizations_path, notice: "Organization updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @organization
      @organization.update!(status: "suspended")
      AuditRecorder.record!(action: "console.organization.suspended", auditable: @organization, organization: @organization)
      redirect_to console_organizations_path, notice: "Organization suspended."
    end

    private
      def set_organization
        @organization = Organization.find(params[:id])
      end

      def organization_params
        params.require(:organization).permit(:name, :slug, :status, :timezone, :locale)
      end
  end
end
