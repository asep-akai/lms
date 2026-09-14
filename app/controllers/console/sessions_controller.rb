module Console
  class SessionsController < Devise::SessionsController
    layout "console_auth"
  end
end
