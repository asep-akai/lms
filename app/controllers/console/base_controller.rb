module Console
  class BaseController < ApplicationController
    before_action :authenticate_admin!
    before_action :set_current_admin
    before_action { authorize :console, :access? }
    after_action :verify_authorized
    after_action :verify_policy_scoped, if: -> { action_name == "index" }
    layout "console"

    private
      def pundit_user = current_admin

      def set_current_admin
        Current.user = current_admin
      end

      def handle_unauthorized
        sign_out current_admin if current_admin
        redirect_to new_admin_session_path, alert: "Your administrator account cannot access the console."
      end
  end
end
