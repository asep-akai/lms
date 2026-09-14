class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include ModalRendering
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized

  private
    def handle_unauthorized
      redirect_to root_path, alert: "You are not authorized to perform that action."
    end
end
