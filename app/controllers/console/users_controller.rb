module Console
  class UsersController < BaseController
    before_action :set_user, only: %i[edit update destroy send_password_reset]

    def index
      authorize User
      @query = TableSearch.normalize(params[:query])
      users = policy_scope(User).left_joins(memberships: :organization)
      @users = TableSearch.call(
        users,
        query: @query,
        columns: %w[users.name users.email users.status organizations.name organizations.slug]
      ).includes(:roles, memberships: :organization).distinct.order(:name)
    end

    def new
      @user = User.new(status: "active")
      authorize @user
    end

    def create
      @user = User.new(create_user_params)
      authorize @user
      @user.invited_at = Time.current
      if @user.save
        AuditRecorder.record!(action: "console.user.created", auditable: @user, metadata: { email: @user.email })
        redirect_to console_users_path, notice: "User created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @user
    end

    def update
      authorize @user
      attributes = update_user_params
      password_changed = attributes[:password].present?

      if @user.update(attributes)
        AuditRecorder.record!(
          action: "console.user.updated",
          auditable: @user,
          metadata: { email: @user.email },
          changes: @user.saved_changes.slice("name", "email", "status")
        )
        if password_changed
          AuditRecorder.record!(action: "console.user.password_changed", auditable: @user, metadata: { email: @user.email })
        end
        redirect_to console_users_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @user
      email = @user.email
      @user.destroy!
      AuditRecorder.record!(action: "console.user.deleted", auditable: @user, metadata: { email: email })
      redirect_to console_users_path, notice: "User deleted."
    end

    def send_password_reset
      authorize @user, :update?
      @user.send_reset_password_instructions
      AuditRecorder.record!(action: "console.user.password_reset_sent", auditable: @user, metadata: { email: @user.email })
      redirect_to console_users_path, notice: "Password reset instructions sent."
    end

    private
      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:name, :email, :status)
      end

      def create_user_params
        params.require(:user).permit(:name, :email, :status, :password, :password_confirmation)
      end

      def update_user_params
        attributes = params.require(:user).permit(:name, :email, :status, :password, :password_confirmation)
        attributes = attributes.except(:password, :password_confirmation) if attributes.values_at(:password, :password_confirmation).all?(&:blank?)
        attributes
      end
  end
end
