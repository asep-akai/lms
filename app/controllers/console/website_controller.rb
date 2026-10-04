module Console
  class WebsiteController < BaseController
    before_action :load_page

    def show
      authorize @page
    end

    def update
      authorize @page
      @page.with_lock do
        if @page.update(page_params)
          @page.social_image.detach if params[:remove_social_image] == "1"
          AuditRecorder.record!(action: "website.updated", auditable: @page, actor: current_admin, organization: nil,
            changes: @page.saved_changes.except("updated_at"))
          redirect_to console_website_path(anchor: page_params.keys.any? { |key| key.start_with?("footer_") } ? "footer" : nil), notice: "Website settings saved to draft.", status: :see_other
        else
          render :show, status: :unprocessable_entity
        end
      end
    end

    def preview
      authorize @page
      @preview = true
      @content = @page.draft_content
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
      render "landing/show", layout: "landing"
    end

    def asset
      authorize @page, :preview?
      attachments = ActiveStorage::Attachment.where(record: @page.sections).or(ActiveStorage::Attachment.where(record: @page))
      attachment = attachments.find_by!(blob_id: params[:id])
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Content-Type-Options"] = "nosniff"
      send_data attachment.download, type: attachment.content_type, filename: attachment.filename.to_s,
        disposition: attachment.content_type == "application/pdf" ? "attachment" : "inline"
    end

    def publish
      authorize @page
      @page.publish!(actor: current_admin)
      redirect_to console_website_path, notice: "Website published. Visitors can now see this version.", status: :see_other
    rescue ActiveRecord::RecordInvalid
      render :show, status: :unprocessable_entity
    end

    def unpublish
      authorize @page
      @page.with_lock do
        @page.update!(current_publication: nil)
        AuditRecorder.record!(action: "website.unpublished", auditable: @page, actor: current_admin, organization: nil)
      end
      redirect_to console_website_path, notice: "Website unpublished. The sign-in page remains available.", status: :see_other
    end

    private
      def load_page
        @page = LandingPage.find_by!(key: "home")
      end

      def page_params
        params.require(:landing_page).permit(:site_name, :title, :description, :social_image,
          :footer_text, :footer_copyright, :footer_background_style, :footer_visible, :footer_workspace_link)
      end
  end
end
