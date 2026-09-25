module ApplicationHelper
  def cloze_text(text)
    safe_join(text.to_s.split("\n", -1).map { |line| ERB::Util.html_escape(line) }, tag.br)
  end

  def current_organization = Current.organization
  def current_membership = Current.membership

  def can?(permission)
    current_user && current_organization && current_user.can?(permission, organization: current_organization)
  end

  def status_badge_class(status)
    status == "active" ? "badge-active" : "badge-suspended"
  end

  def support_status_badge_class(status)
    {
      "open" => "badge-active",
      "in_progress" => "badge-info",
      "waiting_for_reporter" => "badge-suspended",
      "resolved" => "badge-neutral"
    }.fetch(status, "badge-neutral")
  end

  def support_priority_badge_class(priority)
    priority.in?(%w[high urgent]) ? "badge-danger" : "badge-neutral"
  end

  def time_zone_label(time_zone)
    Time.current.in_time_zone(time_zone).strftime("%Z")
  end

  def wib_time(time)
    time&.in_time_zone(Organization::TIME_ZONE)
  end

  def modal_link_to(name, url, **options)
    modal_url = url_for(url).include?("?") ? "#{url_for(url)}&modal=1" : "#{url_for(url)}?modal=1"
    data = options.delete(:data).to_h.merge(turbo_frame: "modal")
    link_to name, modal_url, **options, data: data
  end

  def back_link_to(name, url, **options)
    classes = [ "btn-secondary", options.delete(:class) ].compact.join(" ")
    link_to name, url, **options, class: classes
  end

  def course_module_path(course_content)
    case course_content.contentable
    when Material
      organization_course_material_path(current_organization, course_content.course, course_content.contentable, from: "course")
    when Quiz
      organization_course_quiz_path(current_organization, course_content.course, course_content.contentable, from: "course")
    end
  end
end
