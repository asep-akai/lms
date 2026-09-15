class Organizations::BaseController < AppController
  before_action :set_current_organization

  private
    def load_module_navigation(contentable)
      return unless Current.membership&.student?

      contents = contentable.course.course_contents.includes(:contentable).ordered.to_a
      current_index = contents.index { |content| content.contentable == contentable }
      return unless current_index

      @previous_course_content = contents[current_index - 1] if current_index.positive?
      @next_course_content = contents[current_index + 1]
    end

    def set_current_organization
      Current.organization = Organization.find_by!(slug: params[:organization_slug])
      Current.membership = current_user.memberships.active.find_by(organization: Current.organization)
      authorize Current.organization, :show?
    end
end
