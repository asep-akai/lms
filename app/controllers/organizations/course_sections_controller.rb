class Organizations::CourseSectionsController < Organizations::BaseController
  before_action :set_course
  before_action :set_section, only: %i[edit update destroy move]

  def new
    @section = @course.course_sections.new
    authorize @course, :arrange_contents?
  end

  def create
    authorize @course, :arrange_contents?
    @section = @course.course_sections.new(section_params)
    @section.position = @course.course_sections.maximum(:position).to_i + 1

    if @section.save
      redirect_to organization_course_path(Current.organization, @course), notice: "Section created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @course, :arrange_contents?
  end

  def update
    authorize @course, :arrange_contents?
    if @section.update(section_params)
      redirect_to organization_course_path(Current.organization, @course, anchor: "course-section-#{@section.id}"), notice: "Section updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @course, :arrange_contents?
    if @section.course_contents.exists?
      redirect_to organization_course_path(Current.organization, @course, anchor: "course-section-#{@section.id}"), alert: "Move or delete this section's modules before deleting it."
    elsif @course.course_sections.count == 1
      redirect_to organization_course_path(Current.organization, @course), alert: "A course must have at least one section."
    else
      @section.destroy!
      resequence_sections
      redirect_to organization_course_path(Current.organization, @course), notice: "Section deleted."
    end
  end

  def move
    authorize @course, :arrange_contents?
    sections = @course.course_sections.ordered.to_a
    current_index = sections.index(@section)
    target_index = params[:direction] == "up" ? current_index - 1 : current_index + 1
    adjacent = sections[target_index] if target_index.between?(0, sections.length - 1)

    if adjacent
      CourseSection.transaction do
        current_position = @section.position
        temporary_position = -@section.id
        @section.update_columns(position: temporary_position)
        adjacent.update!(position: current_position)
        @section.update!(position: params[:direction] == "up" ? current_position - 1 : current_position + 1)
      end
    end
    redirect_to organization_course_path(Current.organization, @course, anchor: "course-section-#{@section.id}"), notice: "Section reordered."
  end

  private
    def set_course
      @course = Current.organization.courses.find(params[:course_id])
    end

    def set_section
      @section = @course.course_sections.find(params[:id])
    end

    def section_params
      params.require(:course_section).permit(:name)
    end

    def resequence_sections
      @course.course_sections.ordered.each_with_index do |section, index|
        section.update_columns(position: index + 1)
      end
    end
end
