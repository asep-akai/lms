module Console
  class AdminsController < BaseController
    before_action :set_admin, only: %i[edit update destroy]

    def index
      authorize Admin
      @admins = policy_scope(Admin).includes(:roles).order(:name)
    end

    def new
      @admin = Admin.new(status: "active")
      authorize @admin
      load_roles
    end

    def create
      @admin = Admin.new(admin_params.except(:role_ids))
      authorize @admin
      generated_password = SecureRandom.base58(32)
      @admin.password = generated_password
      @admin.password_confirmation = generated_password
      Admin.transaction do
        @admin.save!
        assign_roles!
        @admin.send_reset_password_instructions
        AuditRecorder.record!(action: "console.admin.created", auditable: @admin, metadata: { email: @admin.email })
      end
      redirect_to console_admins_path, notice: "Administrator created and invited."
    rescue ActiveRecord::RecordInvalid
      load_roles
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @admin
      load_roles
    end

    def update
      authorize @admin
      Admin.transaction do
        @admin.update!(admin_params.except(:role_ids))
        assign_roles!
        AuditRecorder.record!(action: "console.admin.updated", auditable: @admin, metadata: { email: @admin.email })
      end
      redirect_to console_admins_path, notice: "Administrator updated."
    rescue ActiveRecord::RecordInvalid
      load_roles
      render :edit, status: :unprocessable_entity
    end

    def destroy
      authorize @admin
      email = @admin.email
      @admin.destroy!
      AuditRecorder.record!(action: "console.admin.deleted", metadata: { email: email })
      redirect_to console_admins_path, notice: "Administrator deleted."
    end

    private
      def set_admin
        @admin = Admin.find(params[:id])
      end

      def admin_params
        params.require(:admin).permit(:name, :email, :status, role_ids: [])
      end

      def assign_roles!
        roles = Role.where(organization: nil, id: admin_params[:role_ids])
        @admin.role_assignments.where.not(role: roles).destroy_all
        roles.each { |role| @admin.role_assignments.find_or_create_by!(role: role) }
        @admin.errors.add(:roles, "must include at least one role") if roles.empty?
        raise ActiveRecord::RecordInvalid, @admin if @admin.errors.any?
      end

      def load_roles
        @roles = Role.where(organization: nil).ordered
      end
  end
end
