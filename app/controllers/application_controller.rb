class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include ModalRendering
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token

  private
    def after_sign_in_path_for(resource)
      stored_location_for(resource) || (resource.is_a?(Admin) ? console_root_path : user_root_path)
    end

    def after_sign_out_path_for(resource_or_scope)
      resource_or_scope.to_s == "admin" ? new_admin_session_path : new_user_session_path
    end

    def paginate(scope, per_page: PageSlice::DEFAULT_PER_PAGE)
      PageSlice.call(scope, page: params[:page], per_page: per_page)
    end

    def handle_invalid_authenticity_token
      reset_session
      destination = request.path.start_with?("/console") ? new_admin_session_path : new_user_session_path
      redirect_to destination, alert: "Your session or sign-in form expired. Please try again."
    end

    def handle_unauthorized
      redirect_to root_path, alert: "You are not authorized to perform that action."
    end
end
