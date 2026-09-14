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
    user = User.find_or_initialize_by(email: membership_params[:email].to_s.downcase.strip)
    new_user = user.new_record?
    if new_user
      user.assign_attributes(
        name: membership_params[:name],
        password: SecureRandom.base58(32),
        password_confirmation: SecureRandom.base58(32),
        invited_at: Time.current
      )
      user.password_confirmation = user.password
      user.save!
    end

    @membership = Current.organization.memberships.create!(user: user, status: "active")
    @membership.role_ids = permitted_role_ids
    user.send_reset_password_instructions if new_user
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
    if removing_last_admin?
      @membership.errors.add(:base, "The organization must keep at least one active administrator.")
      load_roles
      return render :edit, status: :unprocessable_entity
    end

    Membership.transaction do
      @membership.update!(status: membership_params[:status])
      @membership.role_ids = permitted_role_ids
      AuditRecorder.record!(action: "membership.updated", auditable: @membership, metadata: { email: @membership.user.email })
    end
    redirect_to organization_memberships_path(Current.organization), notice: "Membership updated."
  rescue ActiveRecord::RecordInvalid
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
    AuditRecorder.record!(action: "membership.deleted", metadata: { email: email })
    redirect_to organization_memberships_path(Current.organization), notice: "Membership removed."
  end

  private
    def set_membership
      @membership = Current.organization.memberships.find(params[:id])
    end

    def membership_params
      params.require(:membership).permit(:name, :email, :status, role_ids: [])
    end

    def permitted_role_ids
      Current.organization.roles.where(id: membership_params[:role_ids]).ids
    end

    def load_roles
      @roles = Current.organization.roles.ordered
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
