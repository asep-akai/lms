abort "Production only" unless Rails.env.production?
Rails.application.credentials.config

role = ActiveRecord::Base.connection.select_one("SELECT rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls FROM pg_roles WHERE rolname = current_user")
abort "Application database role has excessive privileges" if role.values.any?
ActiveRecord::Base.configurations.configs_for(env_name: "production").each do |database|
  connection_class = Class.new(ActiveRecord::Base) { self.abstract_class = true }
  # Active Record requires a named class for independent connection pools.
  Object.const_set(:ProductionConnectionProbe, connection_class)
  begin
    connection_class.establish_connection(database)
    connection_class.connection.select_value("SELECT 1")
    puts "Database #{database.name}: reachable"
  ensure
    connection_class.connection_pool.disconnect!
    Object.send(:remove_const, :ProductionConnectionProbe)
  end
end

deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Integer(ENV.fetch("LMS_VERIFY_WORKER_WAIT_SECONDS", "0")).clamp(0, 60)
worker_scope = SolidQueue::Process.where(kind: "Worker")
worker_scope = worker_scope.where(hostname: ENV["LMS_VERIFY_WORKER_HOSTNAME"]) if ENV["LMS_VERIFY_WORKER_HOSTNAME"].present?
loop do
  break if worker_scope.where("last_heartbeat_at > ?", 2.minutes.ago).exists?
  break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  sleep 1
end
workers = worker_scope.where("last_heartbeat_at > ?", 2.minutes.ago).count
failures = SolidQueue::FailedExecution.count
puts "Workers with recent heartbeat: #{workers}; failed jobs: #{failures}"
abort "No recent worker heartbeat" if workers.zero?
abort "Failed jobs require review" if failures.positive?
puts "Credentials, database connections, role privileges, and worker checks passed. External delivery still needs a smoke test."
