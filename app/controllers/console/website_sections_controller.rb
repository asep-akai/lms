module Console
  class WebsiteSectionsController < BaseController
    before_action :load_page
    before_action :load_section, only: %i[edit update destroy move]

    def new
      @section = @page.sections.new
    end

    def create
      @page.with_lock do
        @section = @page.sections.new(section_params.merge(position: (@page.sections.maximum(:position) || -1) + 1))
        if @section.save
          record_change("created")
          redirect_to console_website_path, notice: "Section added to draft.", status: :see_other
        else
          render :new, status: :unprocessable_entity
        end
      end
    end

    def edit
    end

    def update
      @page.with_lock do
        if @section.update(section_params)
          @section.image.detach if params[:remove_image] == "1"
          @section.brochure.detach if params[:remove_brochure] == "1"
          record_change("updated")
          redirect_to console_website_path, notice: "Section saved to draft.", status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @page.with_lock do
        record_change("deleted")
        @section.destroy!
      end
      redirect_to console_website_path, notice: "Section removed from draft. The published page is unchanged.", status: :see_other
    end

    def move
      @page.with_lock do
        sections = @page.sections.to_a
        index = sections.index(@section)
        target = index + (params[:direction] == "up" ? -1 : 1)
        if %w[up down].include?(params[:direction]) && target.between?(0, sections.length - 1)
          sections[index], sections[target] = sections[target], sections[index]
          sections.each_with_index { |section, position| section.update!(position: position) }
          record_change("reordered")
        end
      end
      redirect_to console_website_path, status: :see_other
    end

    private
      def load_page
        @page = LandingPage.find_by!(key: "home")
        authorize @page, :edit?
      end

      def load_section
        @section = @page.sections.find(params[:id])
      end

      def section_params
        params.require(:landing_section).permit(:layout, :eyebrow, :heading, :body, :highlights, :button_label, :button_url,
          :image_alt, :visible, :image, :brochure, :illustration, :image_position, :background_style)
      end

      def record_change(action)
        AuditRecorder.record!(action: "website.section_#{action}", auditable: @page, actor: current_admin, organization: nil,
          metadata: { section_id: @section.id, heading: @section.heading, layout: @section.layout },
          changes: @section.saved_changes.except("created_at", "updated_at", "body", "highlights"))
      end
  end
end
