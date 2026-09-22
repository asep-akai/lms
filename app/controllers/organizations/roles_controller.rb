class Organizations::RolesController < Organizations::BaseController
  before_action :set_role, only: %i[edit update destroy]

  def index
    authorize Role
    @query = TableSearch.normalize(params[:query])
    roles = TableSearch.call(
      policy_scope(Role),
      query: @query,
      columns: %w[roles.name roles.key roles.description]
    )
    @roles = roles.includes(:permissions).ordered
  end

  def new
    @role = Current.organization.roles.new
    authorize @role
    load_permissions
    render_modal(partial: "organizations/roles/form", locals: { role: @role }) if modal_request?
  end

  def create
    @role = Current.organization.roles.new(role_params.except(:permission_ids))
    authorize @role
    @role.permission_ids = permitted_permission_ids
    if @role.save
      AuditRecorder.record!(action: "role.created", auditable: @role, metadata: { name: @role.name })
      redirect_to organization_roles_path(Current.organization), notice: "Role created."
    else
      load_permissions
      modal_request? ? render_modal(partial: "organizations/roles/form", locals: { role: @role }, status: :unprocessable_entity) : render(:new, status: :unprocessable_entity)
    end
  end

  def edit
    authorize @role
    load_permissions
    render_modal(partial: "organizations/roles/form", locals: { role: @role }) if modal_request?
  end

  def update
    authorize @role
    previous_permissions = @role.permissions.order(:key).pluck(:key)
    if @role.update(role_attributes_for_update.merge(permission_ids: permitted_permission_ids))
      changes = @role.saved_changes.slice("name", "key", "description").merge(
        "permissions" => [ previous_permissions, @role.permissions.order(:key).pluck(:key) ]
      )
      AuditRecorder.record!(
        action: "role.updated",
        auditable: @role,
        metadata: { name: @role.name },
        changes: changes
      )
      redirect_to organization_roles_path(Current.organization), notice: "Role updated."
    else
      load_permissions
      modal_request? ? render_modal(partial: "organizations/roles/form", locals: { role: @role }, status: :unprocessable_entity) : render(:edit, status: :unprocessable_entity)
    end
  end

  def destroy
    authorize @role
    if @role.destroy
      AuditRecorder.record!(action: "role.deleted", auditable: @role, metadata: { name: @role.name, key: @role.key })
      redirect_to organization_roles_path(Current.organization), notice: "Role deleted."
    else
      redirect_to organization_roles_path(Current.organization), alert: @role.errors.full_messages.to_sentence
    end
  end

  private
    def set_role
      @role = Current.organization.roles.find(params[:id])
    end

    def role_params
      params.require(:role).permit(:name, :key, :description, permission_ids: [])
    end

    def permitted_permission_ids
      Permission.organization_assignable.where(id: role_params[:permission_ids]).ids
    end

    def role_attributes_for_update
      attributes = role_params.except(:permission_ids)
      @role.system? ? attributes.except(:key) : attributes
    end

    def load_permissions
      @permission_groups = Permission.organization_assignable.organization_groups
    end
end
