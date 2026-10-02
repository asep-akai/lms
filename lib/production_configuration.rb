module ProductionConfiguration
  REQUIRED = %w[APP_HOST RAILS_MASTER_KEY POSTGRES_HOST POSTGRES_USER LMS_DATABASE_PASSWORD
    MAIL_FROM SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD].freeze
  BOOLEANS = %w[SMTP_ENABLE_STARTTLS_AUTO SMTP_SSL HSTS_ENABLED HSTS_SUBDOMAINS].freeze

  def self.errors(env)
    errors = REQUIRED.filter_map do |name|
      value = env[name].to_s
      "#{name} must be configured (not a placeholder)" if value.empty? || value.match?(/replace-with|example\.com|change-me/i)
    end
    host = env["APP_HOST"].to_s
    unless host.match?(/\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/i) && host.include?(".")
      errors << "APP_HOST must be a DNS hostname without a scheme, port, or path"
    end
    errors << "RAILS_MASTER_KEY must be a 32-character hexadecimal credentials key" unless env["RAILS_MASTER_KEY"].to_s.match?(/\A[0-9a-f]{32}\z/i)
    errors << "MAIL_FROM must be a single email address" unless env["MAIL_FROM"].to_s.match?(/\A[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+\z/)
    errors << "LMS_DATABASE_PASSWORD must contain at least 24 characters" if env["LMS_DATABASE_PASSWORD"].to_s.length < 24
    %w[POSTGRES_USER POSTGRES_DB POSTGRES_CACHE_DB POSTGRES_CABLE_DB].each do |name|
      errors << "#{name} must be a PostgreSQL identifier (1-63 characters)" unless env[name].to_s.match?(/\A[a-z_][a-z0-9_]{0,62}\z/)
    end
    databases = env.values_at("POSTGRES_DB", "POSTGRES_CACHE_DB", "POSTGRES_CABLE_DB")
    errors << "Primary, cache, and cable database names must differ" unless databases.uniq.size == 3
    errors << "Do not use PostgreSQL system databases for the application" if (databases & %w[postgres template0 template1]).any?
    BOOLEANS.each do |name|
      errors << "#{name} must be true or false" unless %w[true false].include?(env[name])
    end
    errors << "Use SMTP_SSL or STARTTLS, not both" if env["SMTP_SSL"] == "true" && env["SMTP_ENABLE_STARTTLS_AUTO"] == "true"
    errors << "SMTP must use SSL or STARTTLS in production" unless env["SMTP_SSL"] == "true" || env["SMTP_ENABLE_STARTTLS_AUTO"] == "true"
    { "SMTP_PORT" => 1..65535, "DATABASE_POOL" => 5..100, "RAILS_MAX_THREADS" => 1..100, "JOB_CONCURRENCY" => 1..32 }.each do |name, range|
      value = Integer(env[name].to_s, exception: false)
      errors << "#{name} must be an integer in #{range}" unless value && range.cover?(value)
    end
    if env["DATABASE_POOL"].to_i < env["RAILS_MAX_THREADS"].to_i
      errors << "DATABASE_POOL must be at least RAILS_MAX_THREADS"
    end
    errors
  end
end

if $PROGRAM_NAME == __FILE__
  errors = ProductionConfiguration.errors(ENV)
  abort errors.join("\n") unless errors.empty?
  puts "Production configuration checks passed (credentials and external delivery still need verification)."
end
