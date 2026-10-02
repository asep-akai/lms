require "test_helper"

class SenderProbeMailer < ApplicationMailer
  def probe
    mail(to: "recipient@school.test", subject: "Sender probe", body: "No external delivery")
  end
end

class ApplicationMailerTest < ActionMailer::TestCase
  test "uses the configured notification sender" do
    previous = ENV["MAIL_FROM"]
    ENV["MAIL_FROM"] = "notifications@school.test"
    assert_equal [ "notifications@school.test" ], SenderProbeMailer.probe.from
  ensure
    ENV["MAIL_FROM"] = previous
  end

  test "Devise uses the same sender setting at boot" do
    assert_equal ENV.fetch("MAIL_FROM", "from@example.com"), Devise.mailer_sender
  end
end
