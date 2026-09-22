module Certificates
  class Generate
    BUILDERS = {
      "QuizAttempt" => Certificates::QuizAttemptBuilder
    }.freeze

    def self.call(source:, issued_by:)
      builder_class = BUILDERS.fetch(source.class.name) do
        raise ArgumentError, "Certificates are not supported for #{source.class.name}"
      end
      builder = builder_class.new(source)
      attributes = builder.attributes
      identity = {
        source: source,
        recipient_membership: attributes.fetch(:recipient_membership),
        certificate_type: attributes.fetch(:certificate_type)
      }

      Certificate.published.find_by(identity) || Certificate.create!(
        identity.merge(
          organization: attributes.fetch(:organization),
          issued_by_membership: issued_by,
          generated_at: Time.current,
          data: attributes.fetch(:data)
        )
      )
    rescue ActiveRecord::RecordNotUnique
      Certificate.published.find_by!(identity)
    end
  end
end
