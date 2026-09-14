class Organizations::BaseController < AppController
  before_action :set_current_organization

  private
    def set_current_organization
      Current.organization = Organization.find_by!(slug: params[:organization_slug])
      Current.membership = current_user.memberships.active.find_by(organization: Current.organization)
      authorize Current.organization, :show?
    end
end
