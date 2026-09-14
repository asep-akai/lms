module Console
  class PasswordsController < Devise::PasswordsController
    layout "console_auth"
  end
end
