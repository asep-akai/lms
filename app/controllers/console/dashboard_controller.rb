module Console
  class DashboardController < BaseController
    def show
      authorize :console, :access?
      @organization_count = Organization.count
      @user_count = User.count
      @admin_count = Admin.count
    end
  end
end
