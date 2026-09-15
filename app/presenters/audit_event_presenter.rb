class AuditEventPresenter
  ACTION_LABELS = {
    "organization.created" => "Created organization",
    "organization.updated" => "Updated organization settings",
    "membership.created" => "Added organization member",
    "membership.updated" => "Updated organization member",
    "membership.user_password_changed" => "Changed member password",
    "membership.deleted" => "Removed organization member",
    "role.created" => "Created organization role",
    "role.updated" => "Updated organization role",
    "role.deleted" => "Deleted organization role",
    "course.created" => "Created course",
    "course.updated" => "Updated course",
    "course.deleted" => "Deleted course",
    "course.enrollments_updated" => "Updated course enrollments",
    "course.content_reordered" => "Reordered course content",
    "quiz.created" => "Created quiz",
    "quiz.updated" => "Updated quiz",
    "quiz.deleted" => "Deleted quiz",
    "quiz.question_created" => "Added quiz question",
    "quiz.question_updated" => "Updated quiz question",
    "quiz.question_deleted" => "Removed quiz question",
    "quiz.question_reordered" => "Reordered quiz question",
    "console.organization.created" => "Created organization",
    "console.organization.updated" => "Updated organization",
    "console.organization.suspended" => "Suspended organization",
    "console.organization.reactivated" => "Reactivated organization",
    "console.user.created" => "Created user account",
    "console.user.updated" => "Updated user account",
    "console.user.password_changed" => "Changed user password",
    "console.user.password_reset_sent" => "Sent user password reset",
    "console.user.deleted" => "Deleted user account",
    "console.admin.created" => "Created console administrator",
    "console.admin.updated" => "Updated console administrator",
    "console.admin.password_changed" => "Changed administrator password",
    "console.admin.deleted" => "Deleted console administrator",
    "console.role.created" => "Created console role",
    "console.role.updated" => "Updated console role",
    "console.role.deleted" => "Deleted console role"
  }.freeze

  TYPE_LABELS = {
    "Admin" => "Console administrator",
    "Course" => "Course",
    "Quiz" => "Quiz",
    "Membership" => "Organization member",
    "Organization" => "Organization",
    "Role" => "Role",
    "User" => "Organization member"
  }.freeze

  FIELD_LABELS = {
    "enrolled_students" => "Enrolled students",
    "question_count" => "Question count",
    "permissions" => "Permissions",
    "roles" => "Roles"
  }.freeze

  RESERVED_METADATA_KEYS = %w[actor changes subject].freeze

  attr_reader :event

  def initialize(event)
    @event = event
  end

  def description
    ACTION_LABELS.fetch(event.action) { event.action.tr("._", " ").humanize }
  end

  def actor_name
    actor_snapshot["name"].presence || actor_snapshot["email"].presence || "System"
  end

  def actor_email
    actor_snapshot["email"].presence
  end

  def actor_type
    return "Automated event" if actor_snapshot.empty?

    type_label(actor_snapshot["type"])
  end

  def subject_name
    subject_snapshot["name"].presence ||
      subject_snapshot["email"].presence ||
      type_label(subject_snapshot["type"]).presence ||
      "Not available"
  end

  def subject_reference
    return if subject_snapshot.empty?

    [ type_label(subject_snapshot["type"]), subject_snapshot["id"] && "##{subject_snapshot['id']}" ].compact.join(" ")
  end

  def detail_rows
    event.metadata
      .except(*RESERVED_METADATA_KEYS)
      .filter_map do |key, value|
        next if value.nil? || (!value.in?([ true, false ]) && value.blank?)

        [ key.to_s.humanize, format_value(value) ]
      end
  end

  def change_rows
    changes.filter_map do |field, values|
      next unless values.is_a?(Hash)

      [
        FIELD_LABELS.fetch(field, field.to_s.humanize),
        format_change_value(values["before"]),
        format_change_value(values["after"])
      ]
    end
  end

  def details?
    change_rows.any? || detail_rows.any?
  end

  def occurred_at(timezone)
    event.occurred_at.in_time_zone(timezone).strftime("%-d %b %Y, %H:%M:%S %Z")
  end

  private
    def actor_snapshot
      @actor_snapshot ||= stored_snapshot("actor").reverse_merge(record_snapshot(event.actor))
    end

    def subject_snapshot
      @subject_snapshot ||= begin
        fallback = record_snapshot(event.auditable).reverse_merge(
          "type" => event.auditable_type,
          "id" => event.auditable_id,
          "name" => event.metadata["name"],
          "email" => event.metadata["email"]
        ).compact

        stored_snapshot("subject").reverse_merge(fallback)
      end
    end

    def stored_snapshot(key)
      event.metadata[key].is_a?(Hash) ? event.metadata[key] : {}
    end

    def changes
      event.metadata["changes"].is_a?(Hash) ? event.metadata["changes"] : {}
    end

    def record_snapshot(record)
      return {} unless record

      person = record.is_a?(Membership) ? record.user : record
      {
        "type" => record.class.name,
        "id" => record.id,
        "name" => person.respond_to?(:name) ? person.name : nil,
        "email" => person.respond_to?(:email) ? person.email : nil
      }.compact
    end

    def type_label(type)
      TYPE_LABELS.fetch(type, type.to_s.underscore.humanize)
    end

    def format_value(value)
      case value
      when Array
        value.map { |item| format_value(item) }.join(", ")
      when Hash
        value.map { |key, item| "#{key.to_s.humanize}: #{format_value(item)}" }.join(", ")
      when true
        "Yes"
      when false
        "No"
      else
        value.to_s
      end
    end

    def format_change_value(value)
      return "Not set" if value.nil?
      return "None" if value.respond_to?(:empty?) && value.empty?

      format_value(value)
    end
end
