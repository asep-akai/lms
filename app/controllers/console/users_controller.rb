module Console
  class UsersController < BaseController
    before_action :set_user, only: %i[edit update destroy]

    def index
      authorize User
      @users = policy_scope(User).order(:name)
    end

    def new
      @user = User.new(status: "active")
      authorize @user
    end

    def create
      @user = User.new(user_params)
      authorize @user
      generated_password = SecureRandom.base58(32)
      @user.password = generated_password
      @user.password_confirmation = generated_password
      @user.invited_at = Time.current
      if @user.save
        @user.send_reset_password_instructions
        AuditRecorder.record!(action: "console.user.created", auditable: @user, metadata: { email: @user.email })
        redirect_to console_users_path, notice: "User created and invited."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @user
    end

    def update
      authorize @user
      if @user.update(user_params)
        AuditRecorder.record!(action: "console.user.updated", auditable: @user, metadata: { email: @user.email })
        redirect_to console_users_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @user
      email = @user.email
      @user.destroy!
      AuditRecorder.record!(action: "console.user.deleted", metadata: { email: email })
      redirect_to console_users_path, notice: "User deleted."
    end

    private
      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:name, :email, :status)
      end
  end
end
