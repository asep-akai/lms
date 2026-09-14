RbacSeeder.call!

admin_email = ENV["ADMIN_EMAIL"]
admin_password = ENV["ADMIN_PASSWORD"]

if admin_email.present? && admin_password.present?
  admin = Admin.find_or_initialize_by(email: admin_email.downcase.strip)
  admin.name = ENV.fetch("ADMIN_NAME", "Platform Administrator")
  admin.status = "active"
  if admin.new_record?
    admin.password = admin_password
    admin.password_confirmation = admin_password
  end
  admin.save!
  admin.role_assignments.find_or_create_by!(role: RbacSeeder.provision_console_role!)
  puts "Console administrator ready: #{admin.email}"
else
  puts "Skipping console administrator. Set ADMIN_EMAIL and ADMIN_PASSWORD to create one."
end

user_email = ENV["APP_USER_EMAIL"]
user_password = ENV["APP_USER_PASSWORD"]

if user_email.present? && user_password.present?
  user = User.find_or_initialize_by(email: user_email.downcase.strip)
  user.name = ENV.fetch("APP_USER_NAME", "Organization Owner")
  user.status = "active"
  if user.new_record?
    user.password = user_password
    user.password_confirmation = user_password
  end
  user.save!

  if ENV["DEFAULT_ORGANIZATION_NAME"].present? && user.memberships.none?
    OrganizationProvisioner.call!(
      organization: Organization.new(
        name: ENV.fetch("DEFAULT_ORGANIZATION_NAME"),
        slug: ENV.fetch("DEFAULT_ORGANIZATION_SLUG", ENV.fetch("DEFAULT_ORGANIZATION_NAME").parameterize),
        timezone: ENV.fetch("DEFAULT_ORGANIZATION_TIMEZONE", "UTC"),
        locale: ENV.fetch("DEFAULT_ORGANIZATION_LOCALE", "en")
      ),
      owner: user
    )
  end
  puts "Application user ready: #{user.email}"
end
