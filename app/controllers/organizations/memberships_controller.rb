class Organizations::MembershipsController < Organizations::BaseController
  before_action :set_membership, only: %i[edit update destroy]

  def index
    authorize Membership
    @memberships = policy_scope(Membership).includes(:user).joins(:user).order("users.name")
  end

  def new
    @membership = Current.organization.memberships.new
    authorize @membership
    load_roles
  end

  def create
    @membership = Current.organization.memberships.new
    authorize @membership
    authorize_admin_role_assignment!
    user = User.find_or_initialize_by(email: membership_params[:email].to_s.downcase.strip)
    new_user = user.new_record?
    if new_user
      user.assign_attributes(
        name: membership_params[:name],
        password: membership_params[:password],
        password_confirmation: membership_params[:password_confirmation],
        invited_at: Time.current
      )
      user.save!
    end

    @membership = Current.organization.memberships.create!(user: user, status: "active")
    @membership.role_ids = permitted_role_ids
    AuditRecorder.record!(action: "membership.created", auditable: @membership, metadata: { email: user.email })
    redirect_to organization_memberships_path(Current.organization), notice: "Member added."
  rescue ActiveRecord::RecordInvalid => error
    @membership ||= Current.organization.memberships.new
    @membership.errors.add(:base, error.record.errors.full_messages.to_sentence)
    load_roles
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @membership
    load_roles
  end

  def update
    authorize @membership
    authorize_admin_role_assignment!
    if removing_last_admin?
      @membership.errors.add(:base, "The organization must keep at least one active administrator.")
      load_roles
      return render :edit, status: :unprocessable_entity
    end

    Membership.transaction do
      password_changed = membership_params[:password].present?
      previous_roles = @membership.roles.order(:name).pluck(:name)
      @membership.user.update!(member_password_params) unless member_password_params.empty?
      @membership.update!(status: membership_params[:status])
      @membership.role_ids = permitted_role_ids
      changes = @membership.saved_changes.slice("status").merge(
        "roles" => [ previous_roles, @membership.roles.order(:name).pluck(:name) ]
      )
      AuditRecorder.record!(
        action: "membership.updated",
        auditable: @membership,
        metadata: { email: @membership.user.email },
        changes: changes
      )
      if password_changed
        AuditRecorder.record!(action: "membership.user_password_changed", auditable: @membership, metadata: { email: @membership.user.email })
      end
    end
    redirect_to organization_memberships_path(Current.organization), notice: "Membership updated."
  rescue ActiveRecord::RecordInvalid => error
    @membership.errors.add(:base, error.record.errors.full_messages.to_sentence)
    load_roles
    render :edit, status: :unprocessable_entity
  end

  def destroy
    authorize @membership
    if last_active_admin?(@membership)
      return redirect_to organization_memberships_path(Current.organization), alert: "The organization must keep at least one active administrator."
    end

    email = @membership.user.email
    @membership.destroy!
    AuditRecorder.record!(action: "membership.deleted", auditable: @membership, metadata: { email: email })
    redirect_to organization_memberships_path(Current.organization), notice: "Membership removed."
  end

  private
    def set_membership
      @membership = Current.organization.memberships.find(params[:id])
    end

    def membership_params
      params.require(:membership).permit(:name, :email, :status, :password, :password_confirmation, role_ids: [])
    end

    def member_password_params
      attributes = membership_params.slice(:password, :password_confirmation)
      attributes.values.all?(&:blank?) ? {} : attributes
    end

    def permitted_role_ids
      assignable_roles.where(id: membership_params[:role_ids]).ids
    end

    def load_roles
      @roles = assignable_roles.ordered
    end

    def assignable_roles
      roles = Current.organization.roles
      Current.membership.organization_admin? ? roles : roles.where.not(key: "admin")
    end

    def authorize_admin_role_assignment!
      return unless admin_role_requested?
      return if Current.membership.organization_admin?

      raise Pundit::NotAuthorizedError
    end

    def admin_role_requested?
      Array(membership_params[:role_ids]).map(&:to_s).include?(admin_role.id.to_s)
    end

    def removing_last_admin?
      last_active_admin?(@membership) &&
        (membership_params[:status] != "active" || !permitted_role_ids.include?(admin_role.id))
    end

    def last_active_admin?(membership)
      membership.active? && membership.roles.include?(admin_role) && active_admin_count == 1
    end

    def active_admin_count
      Current.organization.memberships.active
        .joins(user: :role_assignments)
        .where(role_assignments: { role_id: admin_role.id })
        .distinct.count
    end

    def admin_role
      @admin_role ||= Current.organization.roles.find_by!(key: "admin")
    end
end
