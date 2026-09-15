class Organizations::MaterialsController < Organizations::BaseController
  before_action :set_course
  before_action :set_material, only: %i[show edit update destroy]

  def index
    authorize Material
    @materials = policy_scope(@course.materials)
      .includes({ cover_image_attachment: :blob }, blocks: { image_attachment: :blob })
      .order(:created_at, :id)
  end

  def show
    authorize @material
    load_module_navigation(@material)
  end

  def new
    @material = @course.materials.new
    @material.blocks.build(block_type: "text", position: 1)
    authorize @material
  end

  def create
    @material = @course.materials.new(material_params)
    authorize @material

    if @material.save
      record_audit("material.created")
      redirect_to organization_course_material_path(Current.organization, @course, @material, from: navigation_source), notice: "Material created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @material
  end

  def update
    authorize @material

    if @material.update(material_params)
      record_audit("material.updated", changes: @material.saved_changes.slice("title", "description"))
      redirect_to organization_course_material_path(Current.organization, @course, @material, from: navigation_source), notice: "Material updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @material
    title = @material.title
    @material.destroy!
    AuditRecorder.record!(action: "material.deleted", auditable: @material, metadata: { title: title })
    destination = navigation_source == "course" ? organization_course_path(Current.organization, @course) : organization_course_materials_path(Current.organization, @course)
    redirect_to destination, notice: "Material deleted."
  end

  private
    def set_course
      @course = Current.organization.courses.find(params[:course_id])
    end

    def set_material
      @material = @course.materials.find(params[:id])
    end

    def material_params
      permitted = params.require(:material).permit(
        :title, :description, :cover_image, :remove_cover_image,
        blocks_attributes: %i[id block_type body_html position image _destroy]
      )
      normalize_block_positions(permitted)
      permitted.delete(:cover_image) if permitted[:cover_image].blank?
      permitted
    end

    def normalize_block_positions(permitted)
      attributes = permitted[:blocks_attributes]
      return unless attributes

      position = 0
      attributes.each_value do |block|
        block.delete(:image) if block[:image].blank?
        next if ActiveModel::Type::Boolean.new.cast(block[:_destroy])

        position += 1
        block[:position] = position
      end
    end

    def record_audit(action, changes: {})
      AuditRecorder.record!(action: action, auditable: @material, metadata: { title: @material.title }, changes: changes)
    end

    def navigation_source
      "course" if params[:from] == "course"
    end
end
