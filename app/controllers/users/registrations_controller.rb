module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_account_update_params, only: :update

    def new
      head :not_found
    end

    def create
      head :not_found
    end

    protected
      def configure_account_update_params
        devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
      end

      def after_update_path_for(_resource)
        root_path
      end
  end
end
