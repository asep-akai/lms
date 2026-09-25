class Organizations::QuizPagesController < Organizations::BaseController
  before_action :set_course
  before_action :set_quiz
  before_action :set_page, only: %i[update destroy move]

  def create
    authorize @quiz, :update?
    @page = @quiz.build_next_page(page_params)

    if @page.save
      record_change("quiz.page_created")
      redirect_to editor_path, notice: "Page added."
    else
      load_editor
      render "organizations/quizzes/edit", status: :unprocessable_entity
    end
  end

  def update
    authorize @quiz, :update?

    if @page.update(page_params)
      record_change("quiz.page_updated")
      redirect_to editor_path, notice: "Page updated."
    else
      load_editor
      render "organizations/quizzes/edit", status: :unprocessable_entity
    end
  end

  def destroy
    authorize @quiz, :update?
    if @quiz.pages.count == 1
      redirect_to editor_path, alert: "A quiz must have at least one page."
    elsif @page.questions.exists?
      redirect_to editor_path, alert: "Move this page's questions before removing it."
    else
      @page.destroy!
      normalize_page_positions
      record_change("quiz.page_deleted")
      redirect_to editor_path, notice: "Page removed."
    end
  end

  def move
    authorize @quiz, :update?
    adjacent = params[:direction] == "up" ? previous_page : next_page
    return redirect_to(editor_path, alert: "That page cannot be moved further.") unless adjacent

    QuizPage.transaction do
      current_position = @page.position
      @page.update_column(:position, 0)
      adjacent.update!(position: current_position)
      @page.update!(position: params[:direction] == "up" ? current_position - 1 : current_position + 1)
      @quiz.resequence_questions_by_page!
    end
    record_change("quiz.page_reordered", direction: params[:direction])
    redirect_to editor_path, notice: "Page moved #{params[:direction]}."
  end

  private
    def set_course
      @course = Current.organization.courses.find(params[:course_id])
      authorize @course, :show?
    end

    def set_quiz
      @quiz = @course.quizzes.find(params[:quiz_id])
    end

    def set_page
      @page = @quiz.pages.find(params[:id])
    end

    def page_params
      permitted = params.require(:quiz_page).permit(
        :title,
        blocks_attributes: %i[id block_type body_html position image _destroy]
      )
      normalize_block_positions(permitted)
      permitted
    end

    def normalize_block_positions(permitted)
      attributes = permitted[:blocks_attributes]
      return unless attributes

      position = 0
      attributes.values.sort_by { |block| block[:position].to_i }.each do |block|
        block.delete(:image) if block[:image].blank?
        next if ActiveModel::Type::Boolean.new.cast(block[:_destroy])

        position += 1
        block[:position] = position
      end
    end

    def previous_page
      @quiz.pages.where("position < ?", @page.position).order(position: :desc).first
    end

    def next_page
      @quiz.pages.where("position > ?", @page.position).order(:position).first
    end

    def normalize_page_positions
      @quiz.pages.each_with_index { |page, index| page.update_column(:position, index + 1) }
      @quiz.resequence_questions_by_page!
    end

    def load_editor
      @pages = @quiz.pages.includes({ blocks: { image_attachment: :blob } }, questions: :answer_options)
      @questions = @quiz.questions.includes(:answer_options, :quiz_page)
      @new_page = @page.new_record? ? @page : @quiz.build_next_page
      @new_question = @quiz.questions.new(question_type: :multiple_choice, quiz_page: @quiz.default_page)
    end

    def record_change(action, metadata = {})
      AuditRecorder.record!(
        action: action,
        auditable: @quiz,
        metadata: { title: @quiz.title, page_id: @page.id, page_title: @page.title }.merge(metadata)
      )
    end

    def editor_path
      edit_organization_course_quiz_path(Current.organization, @course, @quiz, from: params[:from] == "course" ? "course" : nil)
    end
end
