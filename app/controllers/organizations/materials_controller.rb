class Organizations::MaterialsController < Organizations::BaseController
  before_action :set_course
  before_action :set_material, only: %i[show edit update destroy]

  def index
    authorize Material
    @materials = policy_scope(@course.materials).with_attached_images.order(:created_at, :id)
  end

  def show
    authorize @material
  end

  def new
    @material = @course.materials.new
    authorize @material
  end

  def create
    @material = @course.materials.new(material_params)
    authorize @material

    if @material.save
      record_audit("material.created")
      redirect_to organization_course_material_path(Current.organization, @course, @material), notice: "Material created."
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
      record_audit("material.updated", changes: @material.saved_changes.slice("title", "body_html"))
      redirect_to organization_course_material_path(Current.organization, @course, @material), notice: "Material updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @material
    title = @material.title
    @material.destroy!
    AuditRecorder.record!(action: "material.deleted", auditable: @material, metadata: { title: title })
    redirect_to organization_course_materials_path(Current.organization, @course), notice: "Material deleted."
  end

  private
    def set_course
      @course = Current.organization.courses.find(params[:course_id])
    end

    def set_material
      @material = @course.materials.find(params[:id])
    end

    def material_params
      params.require(:material).permit(:title, :body_html, images: [])
    end

    def record_audit(action, changes: {})
      AuditRecorder.record!(action: action, auditable: @material, metadata: { title: @material.title }, changes: changes)
    end
end
