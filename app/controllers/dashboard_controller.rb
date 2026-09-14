class DashboardController < AppController
  def index
    authorize :dashboard, :show?
    @organizations = policy_scope(Organization).order(:name)
  end
end
