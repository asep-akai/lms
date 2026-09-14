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
end
