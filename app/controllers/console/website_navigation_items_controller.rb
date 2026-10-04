module Console
  class WebsiteNavigationItemsController < BaseController
    before_action :load_page
    before_action :load_item, only: %i[edit update destroy move]

    def new
      @item = @page.navigation_items.new(placement: params[:placement].presence || "header")
    end

    def create
      @page.with_lock do
        @item = @page.navigation_items.new(item_params)
        @item.position = (@page.navigation_items.where(placement: @item.placement).maximum(:position) || -1) + 1
        if @item.save
          record_change("created")
          redirect_to console_website_path(anchor: @item.editor_anchor), notice: "Navigation link added to draft.", status: :see_other
        else
          render :new, status: :unprocessable_entity
        end
      end
    end

    def edit
    end

    def update
      @page.with_lock do
        if @item.update(item_params)
          record_change("updated")
          redirect_to console_website_path(anchor: @item.editor_anchor), notice: "Navigation link saved to draft.", status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @page.with_lock do
        record_change("deleted")
        @item.destroy!
      end
      redirect_to console_website_path(anchor: @item.editor_anchor), notice: "Navigation link removed from draft.", status: :see_other
    end

    def move
      @page.with_lock do
        items = @page.navigation_items.where(placement: @item.placement).to_a
        index = items.index(@item)
        target = index + (params[:direction] == "up" ? -1 : 1)
        if %w[up down].include?(params[:direction]) && target.between?(0, items.size - 1)
          items[index], items[target] = items[target], items[index]
          items.each_with_index { |item, position| item.update!(position: position) }
          record_change("reordered")
        end
      end
      redirect_to console_website_path(anchor: @item.editor_anchor), status: :see_other
    end

    private
      def load_page
        @page = LandingPage.find_by!(key: "home")
        authorize @page, :edit?
      end

      def load_item
        @item = @page.navigation_items.find(params[:id])
      end

      def item_params
        fields = %i[label landing_section_id url visible]
        fields << :placement if action_name == "create"
        params.require(:landing_navigation_item).permit(*fields)
      end

      def record_change(action)
        AuditRecorder.record!(action: "website.navigation_#{action}", auditable: @page, actor: current_admin, organization: nil,
          metadata: { navigation_item_id: @item.id, label: @item.label }, changes: @item.saved_changes.except("created_at", "updated_at"))
      end
  end
end
