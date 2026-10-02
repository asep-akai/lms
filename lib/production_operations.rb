require "json"
require "open3"
require "digest"
require "fileutils"
require "io/console"
require "time"
require_relative "production_configuration"

class ProductionOperations
  class Failure < StandardError; end
  ROOT = File.realpath(File.expand_path("..", __dir__))
  ARCHIVES = %w[primary.dump cache.dump cable.dump storage.tar.gz].freeze

  def initialize
    @project = ENV.fetch("LMS_PROJECT", "lms-production")
    raise Failure, "Use lms-production, lms-rehearsal-NAME, or lms-restore-NAME; development is never a target." unless @project.match?(/\Alms-(?:production|(?:rehearsal|restore)-[a-z0-9-]+)\z/)
    @env_file = File.expand_path(ENV.fetch("LMS_ENV_FILE", ".env.production"), ROOT)
    @compose = [ "docker", "compose", "--project-directory", ROOT, "--env-file", @env_file,
      "-p", @project, "-f", File.join(ROOT, "compose.production.yaml") ]
  end

  def run(arguments)
    action, *args = arguments
    if action.nil? || action == "help"
      puts "Commands: check, status, verify, monitor, bootstrap-admin, backup DIRECTORY, backup-to-restic, restore DIRECTORY, deploy DIRECTORY"
      puts "Select with LMS_ENV_FILE and LMS_PROJECT. Backup directories must be outside the checkout."
      return
    end
    raise Failure, "Unknown command" unless %w[check status verify monitor bootstrap-admin backup backup-to-restic restore deploy].include?(action)
    expected = %w[backup restore deploy].include?(action) ? 1 : 0
    raise Failure, "#{action} expects #{expected} argument(s)" unless args.size == expected
    raise Failure, "Environment file missing" unless File.file?(@env_file)
    raise Failure, "Environment file must not be group/world-accessible (chmod 600)." unless (File.stat(@env_file).mode & 0o077).zero?
    Dir.chdir(ROOT) do
      if %w[backup backup-to-restic restore deploy bootstrap-admin monitor].include?(action)
        FileUtils.mkdir_p(File.join(ROOT, "tmp"))
        File.open(File.join(ROOT, "tmp", "#{@project}-operations.lock"), File::RDWR | File::CREAT, 0o600) do |lock|
          unless lock.flock(File::LOCK_EX | File::LOCK_NB)
            if action == "monitor"
              puts "Health probe skipped during an active maintenance operation."
              return
            end
            raise Failure, "Another operation is running for #{@project}"
          end
          dispatch(action, args)
        end
      else
        dispatch(action, args)
      end
    end
  end

  def dispatch(action, args)
    case action
    when "check" then check
    when "status" then command(*@compose, "ps", "--all")
    when "verify" then verify
    when "monitor"
      verify(wait: 0)
      marker = File.join(ENV.fetch("LMS_BACKUP_ROOT"), "#{@project}-last-success")
      max_age = Integer(ENV.fetch("LMS_BACKUP_MAX_AGE_HOURS", "26")) * 3600
      raise Failure, "No recent successful encrypted backup" unless max_age.positive? && File.file?(marker) && Time.now - Time.iso8601(File.read(marker)) <= max_age
      puts "Backup freshness passed. External HTTPS/expiry monitoring must run outside this VPS."
    when "bootstrap-admin" then bootstrap
    when "backup" then backup(args.first)
    when "backup-to-restic" then backup_to_restic
    when "restore" then restore(args.first)
    when "deploy"
      check
      backup(args.first, resume: false)
      command(*@compose, "up", "-d", "--no-build", "--no-deps", "--wait", "--wait-timeout", "180", "web")
      command(*@compose, "exec", "-T", "web", "bin/rails", "runner", "RbacSeeder.call!")
      command(*@compose, "up", "-d", "--no-build", "--no-deps", "jobs")
      begin
        verify
      rescue Failure
        command(*@compose, "stop", "jobs")
        raise
      end
      puts "Release checks passed. Complete browser and external-service smoke tests before reopening access."
    end
  end

  def verify(wait: 30)
    worker_id = capture(*@compose, "ps", "--status", "running", "-q", "jobs").strip
    raise Failure, "Expected one running jobs container" unless worker_id.match?(/\A[0-9a-f]+\z/)
    worker_host = capture("docker", "inspect", "--format", "{{.Config.Hostname}}", worker_id).strip
    command(*@compose, "exec", "-T", "-e", "LMS_VERIFY_WORKER_WAIT_SECONDS=#{wait}",
      "-e", "LMS_VERIFY_WORKER_HOSTNAME=#{worker_host}", "web", "bin/rails", "runner", "script/production/verify.rb")
  end

  def configuration
    @configuration ||= JSON.parse(capture(*@compose, "config", "--format", "json"))
  end

  def check
    web = configuration.fetch("services").fetch("web").fetch("environment")
    db = configuration.fetch("services").fetch("db").fetch("environment")
    errors = ProductionConfiguration.errors(web)
    errors << "Database admin and app usernames must differ" if db["POSTGRES_USER"] == web["POSTGRES_USER"]
    admin_password = db["POSTGRES_PASSWORD"].to_s
    errors << "POSTGRES_ADMIN_PASSWORD must be a non-placeholder secret of at least 24 characters" if admin_password.size < 24 || admin_password.match?(/replace-with|change-me/i)
    errors << "Database admin and app passwords must differ" if admin_password == web["LMS_DATABASE_PASSWORD"]
    errors << "POSTGRES_ADMIN_USER must be a lowercase PostgreSQL identifier" unless db["POSTGRES_USER"].to_s.match?(/\A[a-z_][a-z0-9_]{0,62}\z/)
    raise Failure, errors.join("\n") unless errors.empty?
    command("docker", "image", "inspect", "--format", "{{.Os}}/{{.Architecture}}", configuration.fetch("services").fetch("web").fetch("image"))
    puts "Settings passed. Image architecture shown above must match the host. No provider credentials were contacted."
  end

  def bootstrap
    raise Failure, "Use an interactive terminal for administrator creation" unless $stdin.tty?
    print "Console administrator email: "
    email = $stdin.gets.to_s.strip
    print "Name: "
    name = $stdin.gets.to_s.strip
    print "Initial password: "
    password = $stdin.noecho(&:gets).to_s.chomp
    puts
    raise Failure, "Email, name, and password are required" if [ email, name, password ].any?(&:empty?)
    command({ "ADMIN_EMAIL" => email, "ADMIN_NAME" => name, "ADMIN_PASSWORD" => password },
      *@compose, "exec", "-T", "-e", "ADMIN_EMAIL", "-e", "ADMIN_NAME", "-e", "ADMIN_PASSWORD", "web", "bin/rails", "db:seed")
  end

  def backup(destination, resume: true)
    destination = File.expand_path(destination)
    raise Failure, "Backup path must be new, outside the checkout, with an existing parent directory" if File.exist?(destination) || !Dir.exist?(File.dirname(destination))
    parent = File.realpath(File.dirname(destination))
    raise Failure, "Backups must be outside the checkout/build context" if parent == ROOT || parent.start_with?(ROOT + "/")
    minimum_kb = Integer(ENV.fetch("LMS_BACKUP_MIN_FREE_MB", "1024")) * 1024
    available_kb = Integer(capture("df", "-Pk", parent).lines.last.split.fetch(3))
    raise Failure, "Insufficient backup staging space (check LMS_BACKUP_MIN_FREE_MB)" unless minimum_kb.positive? && available_kb >= minimum_kb
    running = capture(*@compose, "ps", "--status", "running", "--services").lines.map(&:strip)
    raise Failure, "Database and web must already be running" unless %w[db web].all? { |service| running.include?(service) }
    web_id = capture(*@compose, "ps", "-q", "web").strip
    image = JSON.parse(capture("docker", "inspect", web_id)).first
    manifest = { project: @project, created_at: Time.now.utc.iso8601,
      image_id: image.fetch("Image"), image_reference: image.dig("Config", "Image"),
      revision: image.dig("Config", "Labels", "org.opencontainers.image.revision") }
    Dir.mkdir(destination, 0o700)
    resume_needed = false
    begin
      resume_needed = true
      command(*@compose, "stop", "-t", "120", "jobs", "web")
      remaining = capture(*@compose, "ps", "--status", "running", "--services").lines.map(&:strip)
      raise Failure, "Writers did not stop" unless (remaining & %w[web jobs]).empty?
      { "primary" => "POSTGRES_DB", "cache" => "POSTGRES_CACHE_DB", "cable" => "POSTGRES_CABLE_DB" }.each do |label, variable|
        stream_file(File.join(destination, "#{label}.dump"), *@compose, "exec", "-T", "db", "sh", "-c", "pg_dump -U \"$POSTGRES_USER\" -d \"$#{variable}\" -Fc")
      end
      stream_file(File.join(destination, "storage.tar.gz"), *@compose, "run", "--rm", "--no-deps", "-T", "--entrypoint", "tar", "web", "-czf", "-", "-C", "/rails/storage", ".")
      File.write(File.join(destination, "manifest.json"), JSON.pretty_generate(manifest), perm: 0o600)
      sums = (ARCHIVES + [ "manifest.json" ]).to_h { |name| [ name, Digest::SHA256.file(File.join(destination, name)).hexdigest ] }
      File.write(File.join(destination, "checksums.json"), JSON.pretty_generate(sums), perm: 0o600)
      verify_archive(destination)
      %w[primary cache cable].each do |name|
        File.open(File.join(destination, "#{name}.dump"), "rb") do |input|
          command(*@compose, "exec", "-T", "db", "pg_restore", "--list", in: input, out: File::NULL)
        end
      end
      command("tar", "-tzf", File.join(destination, "storage.tar.gz"), out: File::NULL)
      File.write(File.join(destination, "COMPLETE"), Time.now.utc.iso8601, perm: 0o600)
      puts "Backup completed: #{destination} (local only until uploaded)."
      resume_needed = resume
    ensure
      if resume_needed
        command(*@compose, "start", "--wait", "--wait-timeout", "180", "web")
        command(*@compose, "start", "jobs") if running.include?("jobs")
      end
    end
  end

  def verify_archive(directory)
    checksums = JSON.parse(File.read(File.join(directory, "checksums.json")))
    (ARCHIVES + [ "manifest.json" ]).each do |name|
      path = File.join(directory, name)
      raise Failure, "Missing or corrupt archive: #{name}" unless File.file?(path) && !File.symlink?(path) && Digest::SHA256.file(path).hexdigest == checksums[name]
    end
  end

  def restore(directory)
    raise Failure, "Restore requires LMS_PROJECT=lms-restore-UNIQUE-NAME" unless @project.start_with?("lms-restore-")
    directory = File.expand_path(directory)
    raise Failure, "Backup is incomplete" unless File.file?(File.join(directory, "COMPLETE"))
    verify_archive(directory)
    check
    manifest = JSON.parse(File.read(File.join(directory, "manifest.json")))
    selected_image = configuration.fetch("services").fetch("web").fetch("image")
    selected_id = capture("docker", "image", "inspect", "--format", "{{.Id}}", selected_image).strip
    raise Failure, "Select the exact backed-up image before restoring" unless selected_id == manifest.fetch("image_id")
    volumes = capture("docker", "volume", "ls", "-q", "--filter", "label=com.docker.compose.project=#{@project}")
    containers = capture("docker", "ps", "-aq", "--filter", "label=com.docker.compose.project=#{@project}")
    raise Failure, "Restore project must have no containers or volumes; choose a new project name" unless volumes.strip.empty? && containers.strip.empty?
    raise Failure, "Set LMS_RESTORE_ISOLATED=yes after isolating SMTP/API egress and selecting the backed-up release" unless ENV["LMS_RESTORE_ISOLATED"] == "yes"
    command(*@compose, "up", "-d", "--wait", "--wait-timeout", "180", "db")
    { "primary" => "POSTGRES_DB", "cache" => "POSTGRES_CACHE_DB", "cable" => "POSTGRES_CABLE_DB" }.each do |label, variable|
      File.open(File.join(directory, "#{label}.dump"), "rb") do |input|
        command(*@compose, "exec", "-T", "db", "sh", "-c",
          "pg_restore --exit-on-error --single-transaction --no-owner --no-acl -U \"$LMS_APP_USER\" -d \"$#{variable}\"", in: input)
      end
    end
    File.open(File.join(directory, "storage.tar.gz"), "rb") do |input|
      command(*@compose, "run", "--rm", "--no-deps", "-T", "--user", "0:0", "--entrypoint", "tar", "web", "-xzf", "-", "-C", "/rails/storage", in: input)
    end
    command(*@compose, "run", "--rm", "--no-deps", "-T", "--user", "0:0", "--entrypoint", "chown", "web", "-R", "1000:1000", "/rails/storage")
    puts "Restored into #{@project}. Web/jobs remain stopped. Inspect data and queued side effects before starting either."
  end

  def backup_to_restic
    %w[RESTIC_REPOSITORY RESTIC_PASSWORD_FILE LMS_BACKUP_ROOT].each do |name|
      raise Failure, "#{name} must be configured" if ENV[name].to_s.empty?
    end
    password_file = ENV.fetch("RESTIC_PASSWORD_FILE")
    raise Failure, "RESTIC_PASSWORD_FILE must be a private file (mode 600)" unless File.file?(password_file) && (File.stat(password_file).mode & 0o077).zero?
    root = File.realpath(ENV.fetch("LMS_BACKUP_ROOT"))
    command("restic", "snapshots", "--compact")
    destination = File.join(root, "#{@project}-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{Process.pid}")
    backup(destination)
    command("restic", "backup", "--tag", @project, destination)
    File.write(File.join(root, "#{@project}-last-success"), Time.now.utc.iso8601, perm: 0o600)
    puts "Encrypted repository upload completed. Local files retained for explicit retention cleanup."
  end

  def stream_file(path, *args)
    File.open(path, "wb", 0o600) { |output| command(*args, out: output) }
  end

  def capture(*args)
    stdout, stderr, status = Open3.capture3(*args)
    raise Failure, "Command failed: #{args.first}\n#{stderr}" unless status.success?
    stdout
  end

  def command(*args, **options)
    raise Failure, "Command failed; inspect the output above. Services may be stopped after a failed deployment/restore." unless system(*args, **options)
  end
end
