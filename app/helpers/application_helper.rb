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
end
