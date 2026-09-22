class DashboardController < AppController
  def index
    authorize :dashboard, :show?
    load_organization_directory

    redirect_to @organizations.first and return if @organizations.one?
  end
end
