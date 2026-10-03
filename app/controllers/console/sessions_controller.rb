module Console
  class SessionsController < Devise::SessionsController
    before_action :prevent_login_form_caching, only: :new

    layout "console_auth"

    private
      def after_sign_in_path_for(_resource)
        console_root_path
      end

      def prevent_login_form_caching
        response.headers["Cache-Control"] = "no-store"
      end
  end
end
