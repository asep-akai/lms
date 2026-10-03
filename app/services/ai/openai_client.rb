require "json"
require "net/http"
require "base64"
require "securerandom"

module Ai
  class OpenaiClient
    Response = Data.define(:data, :model, :response_id)
    Media = Data.define(:label, :mime_type, :data, :display_name)

    RESPONSES_ENDPOINT = "https://api.openai.com/v1/responses".freeze
    TRANSCRIPTIONS_ENDPOINT = "https://api.openai.com/v1/audio/transcriptions".freeze
    MAX_AUDIO_SIZE = 25.megabytes

    def initialize(
      api_key: ENV["OPENAI_API_KEY"],
      model: ENV.fetch("OPENAI_MODEL", "gpt-6-luna"),
      transcription_model: ENV.fetch("OPENAI_TRANSCRIPTION_MODEL", "gpt-transcribe"),
      transport: ApiTransport.new(read_timeout: 90)
    )
      @api_key = api_key
      @model = model
      @transcription_model = transcription_model
      @transport = transport
    end

    def generate_json(system_instruction:, prompt:, schema:, media: [])
      validate_configuration!
      content, transcriptions = build_content(prompt, media)
      response = transport.call(build_response_request(system_instruction:, content:, schema:))
      body = parse_body(response.body)
      ensure_success!(response, body)

      text = extract_output_text(body)
      raise ProviderError, "OpenAI returned no analysis." if text.blank?

      data = JSON.parse(text)
      data["transcriptions"] = transcriptions if transcriptions.any?
      Response.new(data:, model:, response_id: body["id"])
    rescue ApiTransport::Error => error
      raise ProviderError, "OpenAI could not be reached: #{error.message}"
    rescue JSON::ParserError
      raise ProviderError, "OpenAI returned an invalid analysis. Please try again."
    end

    private
      attr_reader :api_key, :model, :transcription_model, :transport

      def validate_configuration!
        raise ConfigurationError, "Add OPENAI_API_KEY to your .env file before using automatic grading." if api_key.blank?
        validate_model!(model, "OPENAI_MODEL")
        validate_model!(transcription_model, "OPENAI_TRANSCRIPTION_MODEL")
      end

      def validate_model!(value, variable)
        raise ConfigurationError, "#{variable} contains unsupported characters." unless value.match?(/\A[a-zA-Z0-9._-]+\z/)
      end

      def build_content(prompt, media)
        transcriptions = []
        content = [ { type: "input_text", text: prompt } ]

        Array(media).each do |item|
          validate_media!(item)
          content << { type: "input_text", text: "Media label: #{item.label}" }
          if item.mime_type.start_with?("image/")
            content << {
              type: "input_image",
              image_url: "data:#{item.mime_type};base64,#{Base64.strict_encode64(item.data)}",
              detail: "auto"
            }
          elsif item.mime_type.start_with?("audio/")
            transcript = transcribe(item)
            content << { type: "input_text", text: "Faithful audio transcript: #{transcript}" }
            if (match = item.label.match(/\Aquestion-(\d+)-student-audio\z/))
              transcriptions << { "question_id" => match[1].to_i, "text" => transcript }
            end
          else
            raise ArgumentError, "OpenAI media must be an image or audio file."
          end
        end

        [ content, transcriptions ]
      end

      def validate_media!(item)
        raise ArgumentError, "OpenAI media must include a label." if item.label.blank?
        raise ArgumentError, "OpenAI media must include a MIME type." if item.mime_type.blank?
        raise ArgumentError, "OpenAI media cannot be empty." if item.data.blank?
      end

      def build_response_request(system_instruction:, content:, schema:)
        request = Net::HTTP::Post.new(URI(RESPONSES_ENDPOINT))
        authorize(request)
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(
          model:,
          instructions: system_instruction,
          input: [ { role: "user", content: } ],
          text: {
            format: {
              type: "json_schema",
              name: "quiz_attempt_analysis",
              strict: true,
              schema: strict_schema(schema)
            }
          },
          store: false
        )
        request
      end

      def transcribe(media)
        raise ProviderError, "Audio responses must be 25 MB or smaller for OpenAI transcription." if media.data.bytesize > MAX_AUDIO_SIZE

        request = Net::HTTP::Post.new(URI(TRANSCRIPTIONS_ENDPOINT))
        authorize(request)
        boundary = "----RubyMultipart#{SecureRandom.hex(16)}"
        request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        request.body = multipart_body(boundary, media)
        response = transport.call(request)
        body = parse_body(response.body)
        ensure_success!(response, body)
        transcript = body["text"].to_s.strip
        raise ProviderError, "OpenAI returned an empty audio transcription." if transcript.blank?

        transcript
      end

      def multipart_body(boundary, media)
        filename = media.display_name.to_s.gsub(/["\r\n]/, "_").presence || "audio"
        body = String.new(encoding: Encoding::BINARY)
        append_field(body, boundary, "model", transcription_model)
        append_field(body, boundary, "response_format", "json")
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
        body << "Content-Type: #{media.mime_type}\r\n\r\n"
        body << media.data.b
        body << "\r\n--#{boundary}--\r\n"
        body
      end

      def append_field(body, boundary, name, value)
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n"
        body << value
        body << "\r\n"
      end

      def authorize(request)
        request["Authorization"] = "Bearer #{api_key}"
      end

      def strict_schema(value)
        return value.map { |item| strict_schema(item) } if value.is_a?(Array)
        return value unless value.is_a?(Hash)

        normalized = value.to_h { |key, item| [ key, strict_schema(item) ] }
        type = normalized[:type] || normalized["type"]
        if type == "object" && !normalized.key?(:additionalProperties) && !normalized.key?("additionalProperties")
          normalized[:additionalProperties] = false
        end
        normalized
      end

      def extract_output_text(body)
        Array(body["output"]).filter_map do |item|
          next unless item["type"] == "message"

          Array(item["content"]).filter_map { |part| part["text"] if part["type"] == "output_text" }.join
        end.join
      end

      def ensure_success!(response, body)
        return if response.is_a?(Net::HTTPSuccess)

        raise ProviderError, body.dig("error", "message") || "OpenAI returned HTTP #{response.code}."
      end

      def parse_body(body)
        JSON.parse(body.presence || "{}")
      rescue JSON::ParserError
        raise ProviderError, "OpenAI returned an unreadable response. Please try again."
      end
  end
end
