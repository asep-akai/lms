require "test_helper"
require "tmpdir"
require_relative "../../lib/production_operations"

class ProductionOperationsTest < ActiveSupport::TestCase
  setup do
    @previous_project = ENV["LMS_PROJECT"]
    @previous_env_file = ENV["LMS_ENV_FILE"]
    ENV["LMS_PROJECT"] = "lms-rehearsal-unit"
    @directory = Dir.mktmpdir("lms-operations-test-")
    @env_file = File.join(@directory, ".env")
    File.write(@env_file, "", perm: 0o600)
    ENV["LMS_ENV_FILE"] = @env_file
  end

  teardown do
    ENV["LMS_PROJECT"] = @previous_project
    ENV["LMS_ENV_FILE"] = @previous_env_file
    FileUtils.remove_entry(@directory)
  end

  test "refuses development and arbitrary project names" do
    %w[lms other-production lms-production/other].each do |project|
      ENV["LMS_PROJECT"] = project
      assert_raises(ProductionOperations::Failure) { ProductionOperations.new }
    end
  end

  test "requires private env files before invoking docker" do
    File.chmod(0o644, @env_file)
    error = assert_raises(ProductionOperations::Failure) { ProductionOperations.new.run([ "check" ]) }
    assert_includes error.message, "chmod 600"
  end

  test "refuses restore into production or rehearsal" do
    %w[lms-production lms-rehearsal-test].each do |project|
      ENV["LMS_PROJECT"] = project
      error = assert_raises(ProductionOperations::Failure) { ProductionOperations.new.restore(@directory) }
      assert_includes error.message, "lms-restore"
    end
  end

  test "refuses existing backup directory and checkout destinations" do
    operations = ProductionOperations.new
    assert_raises(ProductionOperations::Failure) { operations.backup(@directory) }
    assert_raises(ProductionOperations::Failure) { operations.backup(File.join(ProductionOperations::ROOT, "tmp", "unsafe-backup")) }
  end

  test "detects modified or missing archive files" do
    checksums = (ProductionOperations::ARCHIVES + [ "manifest.json" ]).to_h do |name|
      path = File.join(@directory, name)
      File.write(path, "synthetic archive")
      [ name, Digest::SHA256.file(path).hexdigest ]
    end
    File.write(File.join(@directory, "checksums.json"), JSON.generate(checksums))
    operations = ProductionOperations.new
    operations.verify_archive(@directory)
    File.write(File.join(@directory, "primary.dump"), "changed")
    error = assert_raises(ProductionOperations::Failure) { operations.verify_archive(@directory) }
    assert_includes error.message, "primary.dump"
  end

  test "validates command arity before doing work" do
    assert_raises(ProductionOperations::Failure) { ProductionOperations.new.run([ "deploy" ]) }
    assert_raises(ProductionOperations::Failure) { ProductionOperations.new.run([ "delete-all" ]) }
  end
end
