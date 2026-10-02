require "test_helper"
require_relative "../../lib/production_configuration"

class ProductionConfigurationTest < ActiveSupport::TestCase
  def valid_environment
    {
      "APP_HOST" => "learn.school.test", "RAILS_MASTER_KEY" => "a" * 32,
      "POSTGRES_HOST" => "db", "POSTGRES_USER" => "lms", "LMS_DATABASE_PASSWORD" => "s" * 32,
      "POSTGRES_DB" => "lms_production", "POSTGRES_CACHE_DB" => "lms_cache", "POSTGRES_CABLE_DB" => "lms_cable",
      "MAIL_FROM" => "notifications@school.test", "SMTP_ADDRESS" => "smtp.school.test",
      "SMTP_USERNAME" => "sender", "SMTP_PASSWORD" => "smtp-secret", "SMTP_PORT" => "587",
      "SMTP_ENABLE_STARTTLS_AUTO" => "true", "SMTP_SSL" => "false", "HSTS_ENABLED" => "true",
      "HSTS_SUBDOMAINS" => "false", "DATABASE_POOL" => "5", "RAILS_MAX_THREADS" => "3", "JOB_CONCURRENCY" => "1"
    }
  end

  test "accepts configured STARTTLS and implicit TLS environments" do
    assert_empty ProductionConfiguration.errors(valid_environment)
    assert_empty ProductionConfiguration.errors(valid_environment.merge("SMTP_PORT" => "465", "SMTP_SSL" => "true", "SMTP_ENABLE_STARTTLS_AUTO" => "false"))
  end

  test "rejects placeholders, malformed settings, and unsafe TLS without printing secrets" do
    environment = valid_environment.merge("APP_HOST" => "https://example.com/path", "SMTP_SSL" => "true",
      "RAILS_MASTER_KEY" => "my-private-invalid-key", "MAIL_FROM" => "bad\naddress", "DATABASE_POOL" => "2")
    errors = ProductionConfiguration.errors(environment).join("\n")
    %w[APP_HOST MAIL_FROM RAILS_MASTER_KEY DATABASE_POOL SMTP_SSL].each { |field| assert_includes errors, field }
    assert_not_includes errors, environment.fetch("RAILS_MASTER_KEY")
    assert_not_includes errors, environment.fetch("SMTP_PASSWORD")
    assert_includes ProductionConfiguration.errors(valid_environment.merge("SMTP_ENABLE_STARTTLS_AUTO" => "false")).join, "SMTP must use"
  end

  test "rejects colliding database names, identifiers, and invalid boolean values" do
    errors = ProductionConfiguration.errors(valid_environment.merge("POSTGRES_CACHE_DB" => "lms_production", "POSTGRES_USER" => "bad;sql", "HSTS_ENABLED" => "yes"))
    assert_equal 3, errors.size
  end
end
