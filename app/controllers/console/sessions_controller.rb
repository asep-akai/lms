module Console
  class SessionsController < Devise::SessionsController
    before_action :prevent_login_form_caching, only: :new

    layout "console_auth"

    private
      def prevent_login_form_caching
        response.headers["Cache-Control"] = "no-store"
      end
  end
end
