class Organizations::MaterialsController < Organizations::BaseController
  before_action :set_course
  before_action :set_material, only: %i[show edit update destroy toggle_completion]

  def index
    authorize Material
    @materials = policy_scope(@course.materials)
      .includes({ cover_image_attachment: :blob }, blocks: { image_attachment: :blob })
      .order(:created_at, :id)
  end

  def show
    authorize @material
    load_module_navigation(@material)
    @material_completed = Current.membership.material_completions.exists?(material: @material) if Current.membership&.student?
  end

  def toggle_completion
    authorize @material, :show?
    raise Pundit::NotAuthorizedError unless Current.membership&.student?

    completion = Current.membership.material_completions.find_by(material: @material)
    if completion
      completion.destroy!
      notice = "Material marked incomplete."
    else
      Current.membership.material_completions.create!(material: @material, completed_at: Time.current)
      notice = "Material finished."
    end
    redirect_to organization_course_material_path(Current.organization, @course, @material, from: "course"), notice: notice
  end

  def new
    @material = @course.materials.new
    @material.course_section_id = params[:course_section_id]
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
    @material.course_section_id = @material.course_content.course_section_id
  end

  def update
    authorize @material

    if @material.update(material_params)
      move_to_selected_section(@material)
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
        :title, :description, :cover_image, :remove_cover_image, :course_section_id,
        blocks_attributes: %i[id block_type body_html position image video_url _destroy]
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

    def move_to_selected_section(material)
      return if material.course_section_id.blank?

      target_section = @course.course_sections.find(material.course_section_id)
      return if material.course_content.course_section == target_section

      move_content_to_section(material.course_content, target_section)
    end

    def move_content_to_section(content, target_section)
      source_section = content.course_section
      content.update!(course_section: target_section, position: target_section.course_contents.maximum(:position).to_i + 1)
      source_section.course_contents.ordered_within_section.each_with_index do |source_content, index|
        source_content.update_columns(position: index + 1)
      end
    end

    def navigation_source
      "course" if params[:from] == "course"
    end
end
