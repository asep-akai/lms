module ModalRendering
  extend ActiveSupport::Concern

  included do
    helper_method :modal_request?
  end

  private
    def modal_request?
      params[:modal] == "1" && turbo_frame_request?
    end

    def render_modal(partial:, locals: {}, status: :ok)
      return unless modal_request?

      render partial: "shared/modal", locals: { content_partial: partial, content_locals: locals }, status: status
    end
end
