module Console
  class RolesController < BaseController
    before_action :set_role, only: %i[edit update destroy]

    def index
      authorize Role
      @query = TableSearch.normalize(params[:query])
      roles = TableSearch.call(
        policy_scope(Role),
        query: @query,
        columns: %w[roles.name roles.key roles.description]
      )
      @roles = roles.includes(:permissions, :role_assignments).ordered
    end

    def new
      @role = Role.new
      authorize @role
      load_permissions
    end

    def create
      @role = Role.new(role_params.except(:permission_ids))
      authorize @role
      @role.permission_ids = permission_ids
      if @role.save
        AuditRecorder.record!(action: "console.role.created", auditable: @role, metadata: { key: @role.key })
        redirect_to console_roles_path, notice: "Role created."
      else
        load_permissions
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @role
      load_permissions
    end

    def update
      authorize @role
      previous_permissions = @role.permissions.order(:key).pluck(:key)
      if @role.update(role_params.except(:permission_ids).merge(permission_ids: permission_ids))
        changes = @role.saved_changes.slice("name", "key", "description").merge(
          "permissions" => [ previous_permissions, @role.permissions.order(:key).pluck(:key) ]
        )
        AuditRecorder.record!(
          action: "console.role.updated",
          auditable: @role,
          metadata: { key: @role.key },
          changes: changes
        )
        redirect_to console_roles_path, notice: "Role updated."
      else
        load_permissions
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @role
      key = @role.key
      if @role.destroy
        AuditRecorder.record!(action: "console.role.deleted", auditable: @role, metadata: { key: key })
        redirect_to console_roles_path, notice: "Role deleted."
      else
        redirect_to console_roles_path, alert: @role.errors.full_messages.to_sentence
      end
    end

    private
      def set_role
        @role = Role.where(organization: nil).find(params[:id])
      end

      def role_params
        params.require(:role).permit(:name, :key, :description, permission_ids: [])
      end

      def permission_ids
        Permission.console_assignable.where(id: role_params[:permission_ids]).ids
      end

      def load_permissions
        @permission_groups = Permission.console_assignable.console_groups
      end
  end
end
