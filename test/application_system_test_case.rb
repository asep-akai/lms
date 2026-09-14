require "test_helper"

ENV["SE_BROWSER_PATH"] ||= "/usr/bin/chromium" if File.exist?("/usr/bin/chromium")

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]
end
