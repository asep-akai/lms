class LandingController < ApplicationController
  layout "landing"

  def home
    response.headers["Cache-Control"] = "private, no-store"
    flash.keep if admin_signed_in? || user_signed_in?
    if admin_signed_in?
      redirect_to console_root_path
    elsif user_signed_in?
      redirect_to user_root_path
    else
      show
      render :show
    end
  end

  def show
    page = LandingPage.find_by(key: "home")
    @content = if page&.current_publication
      page.current_publication.content
    elsif page.nil? || page.default_template?
      LandingPageStarter.default_content
    end
    response.headers["Cache-Control"] = "no-store"
  end

  def asset
    publication = LandingPage.find_by(key: "home")&.current_publication
    raise ActiveRecord::RecordNotFound unless publication

    attachment = publication.assets.find_by!(blob_id: params[:id])
    send_landing_asset(attachment)
  end

  private
    def send_landing_asset(attachment)
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Content-Type-Options"] = "nosniff"
      send_data attachment.download, type: attachment.content_type, filename: attachment.filename.to_s,
        disposition: attachment.content_type == "application/pdf" ? "attachment" : "inline"
    end
end
