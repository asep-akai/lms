module ApplicationHelper
  def current_organization = Current.organization
  def current_membership = Current.membership

  def can?(permission)
    current_user && current_organization && current_user.can?(permission, organization: current_organization)
  end

  def status_badge_class(status)
    status == "active" ? "badge-active" : "badge-suspended"
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
