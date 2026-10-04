class WebsiteLinkValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    uri = URI.parse(value)
    valid = !value.match?(/[\s\\]/) && (
      (uri.scheme == "https" && uri.host.present? && uri.userinfo.nil?) ||
      (uri.scheme == "mailto" && uri.opaque.present?) ||
      value.match?(%r{\A/(?!/)[a-zA-Z0-9/_?=&%#.-]*\z}) ||
      value.match?(/\A#[a-zA-Z][a-zA-Z0-9_-]*\z/))
    record.errors.add(attribute, "must be an HTTPS URL, email link, local path, or section anchor") unless valid
  rescue URI::InvalidURIError
    record.errors.add(attribute, "is not a valid URL")
  end
end
