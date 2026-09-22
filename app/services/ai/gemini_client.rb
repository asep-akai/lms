require "json"
require "net/http"

module Ai
  class GeminiClient
    Response = Data.define(:data, :model, :response_id)

    ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models".freeze

    def initialize(
      api_key: ENV["GEMINI_API_KEY"],
      model: ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash"),
      transport: ApiTransport.new(read_timeout: 45)
    )
      @api_key = api_key
      @model = model
      @transport = transport
    end

    def generate_json(system_instruction:, prompt:, schema:)
      validate_configuration!
      response = transport.call(build_request(system_instruction:, prompt:, schema:))
      body = parse_body(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        message = body.dig("error", "message") || "Gemini returned HTTP #{response.code}."
        raise ProviderError, message
      end

      text = body.dig("candidates", 0, "content", "parts")&.filter_map { |part| part["text"] }&.join
      raise ProviderError, "Gemini returned no analysis." if text.blank?

      Response.new(
        data: JSON.parse(text),
        model: model,
        response_id: body["responseId"]
      )
    rescue ApiTransport::Error => error
      raise ProviderError, "Gemini could not be reached: #{error.message}"
    rescue JSON::ParserError
      raise ProviderError, "Gemini returned an invalid analysis. Please try again."
    end

    private
      attr_reader :api_key, :model, :transport

      def validate_configuration!
        raise ConfigurationError, "Add GEMINI_API_KEY to your .env file before using automatic grading." if api_key.blank?
        raise ConfigurationError, "GEMINI_MODEL contains unsupported characters." unless model.match?(/\A[a-zA-Z0-9._-]+\z/)
      end

      def build_request(system_instruction:, prompt:, schema:)
        uri = URI("#{ENDPOINT}/#{model}:generateContent")
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["x-goog-api-key"] = api_key
        request.body = JSON.generate(
          systemInstruction: { parts: [ { text: system_instruction } ] },
          contents: [ { role: "user", parts: [ { text: prompt } ] } ],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: schema
          }
        )
        request
      end

      def parse_body(body)
        JSON.parse(body.presence || "{}")
      rescue JSON::ParserError
        raise ProviderError, "Gemini returned an unreadable response. Please try again."
      end
  end
end
