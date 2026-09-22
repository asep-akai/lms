class AppController < ApplicationController
  before_action :authenticate_user!
  before_action :set_current_user
  after_action :verify_authorized

  helper_method :current_organization, :current_membership, :can?

  private
    def set_current_user
      Current.user = current_user
    end

    def current_organization = Current.organization
    def current_membership = Current.membership

    def can?(permission)
      Current.organization.present? && current_user.can?(permission, organization: Current.organization)
    end

    def load_organization_directory
      @organizations = policy_scope(Organization).order(:name).to_a
      organization_ids = @organizations.map(&:id)
      @roles_by_organization_id = current_user.roles
        .where(organization_id: organization_ids)
        .ordered
        .group_by(&:organization_id)
    end

    def handle_unauthorized
      message = if Current.organization.present? && !Current.organization.active?
        "This organization is suspended and cannot be accessed."
      else
        "You are not authorized to perform that action."
      end

      redirect_to root_path, alert: message
    end
end
