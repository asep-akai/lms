require "test_helper"

ENV["SE_BROWSER_PATH"] ||= "/usr/bin/chromium" if File.exist?("/usr/bin/chromium")

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  STANDARD_SCREEN_SIZE = [ 1400, 1000 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end

  setup do
    Capybara.reset_sessions!
    page.current_window.resize_to(*STANDARD_SCREEN_SIZE)
  end
  teardown { page.current_window.resize_to(*STANDARD_SCREEN_SIZE) }
end
