require "json"
require "net/http"
require "base64"

module Ai
  class GeminiClient
    Response = Data.define(:data, :model, :response_id)
    Media = Data.define(:label, :mime_type, :data, :display_name)

    ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models".freeze
    FILES_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/files".freeze
    FILE_UPLOAD_ENDPOINT = "https://generativelanguage.googleapis.com/upload/v1beta/files".freeze
    INLINE_MEDIA_LIMIT = 12 * 1024 * 1024

    def initialize(
      api_key: ENV["GEMINI_API_KEY"],
      model: ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash"),
      transport: ApiTransport.new(read_timeout: 45)
    )
      @api_key = api_key
      @model = model
      @transport = transport
    end

    def generate_json(system_instruction:, prompt:, schema:, media: [])
      validate_configuration!
      uploaded_files = []
      parts = build_parts(prompt, media, uploaded_files)
      response = transport.call(build_request(system_instruction:, parts:, schema:))
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
    ensure
      uploaded_files&.each { |file| delete_file(file.fetch("name")) }
    end

    private
      attr_reader :api_key, :model, :transport

      def validate_configuration!
        raise ConfigurationError, "Add GEMINI_API_KEY to your .env file before using automatic grading." if api_key.blank?
        raise ConfigurationError, "GEMINI_MODEL contains unsupported characters." unless model.match?(/\A[a-zA-Z0-9._-]+\z/)
      end

      def build_parts(prompt, media, uploaded_files)
        media = Array(media)
        return [ { text: prompt } ] if media.empty?

        validate_media!(media)
        inline = media.sum { |item| item.data.bytesize } <= INLINE_MEDIA_LIMIT
        [ { text: prompt } ] + media.flat_map do |item|
          media_part = if inline
            { inlineData: { mimeType: item.mime_type, data: Base64.strict_encode64(item.data) } }
          else
            file = upload_file(item)
            uploaded_files << file
            { fileData: { mimeType: item.mime_type, fileUri: file.fetch("uri") } }
          end
          [ { text: "Media label: #{item.label}" }, media_part ]
        end
      end

      def validate_media!(media)
        media.each do |item|
          raise ArgumentError, "Gemini media must include a label." if item.label.blank?
          raise ArgumentError, "Gemini media must include a MIME type." if item.mime_type.blank?
          raise ArgumentError, "Gemini media cannot be empty." if item.data.blank?
        end
      end

      def build_request(system_instruction:, parts:, schema:)
        uri = URI("#{ENDPOINT}/#{model}:generateContent")
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["x-goog-api-key"] = api_key
        request.body = JSON.generate(
          systemInstruction: { parts: [ { text: system_instruction } ] },
          contents: [ { role: "user", parts: parts } ],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: schema
          }
        )
        request
      end

      def upload_file(media)
        start_request = Net::HTTP::Post.new(URI(FILE_UPLOAD_ENDPOINT))
        start_request["x-goog-api-key"] = api_key
        start_request["Content-Type"] = "application/json"
        start_request["X-Goog-Upload-Protocol"] = "resumable"
        start_request["X-Goog-Upload-Command"] = "start"
        start_request["X-Goog-Upload-Header-Content-Length"] = media.data.bytesize.to_s
        start_request["X-Goog-Upload-Header-Content-Type"] = media.mime_type
        start_request.body = JSON.generate(file: { display_name: media.display_name.to_s.first(512) })
        start_response = transport.call(start_request)
        ensure_success!(start_response, "start the media upload")

        upload_url = start_response["x-goog-upload-url"]
        raise ProviderError, "Gemini did not provide a media upload URL." if upload_url.blank?

        upload_request = Net::HTTP::Post.new(URI(upload_url))
        upload_request["Content-Type"] = media.mime_type
        upload_request["Content-Length"] = media.data.bytesize.to_s
        upload_request["X-Goog-Upload-Offset"] = "0"
        upload_request["X-Goog-Upload-Command"] = "upload, finalize"
        upload_request.body = media.data
        upload_response = transport.call(upload_request)
        ensure_success!(upload_response, "upload media")
        wait_until_active(parse_body(upload_response.body).fetch("file"))
      end

      def wait_until_active(file)
        30.times do
          state = file["state"]
          return file if state.blank? || state == "ACTIVE"
          raise ProviderError, "Gemini could not process an uploaded media file." if state == "FAILED"

          sleep 0.5
          file = fetch_file(file.fetch("name"))
        end
        raise ProviderError, "Gemini took too long to process an uploaded media file. Please try again."
      end

      def fetch_file(name)
        request = Net::HTTP::Get.new(URI("https://generativelanguage.googleapis.com/v1beta/#{name}"))
        request["x-goog-api-key"] = api_key
        response = transport.call(request)
        ensure_success!(response, "check uploaded media")
        parse_body(response.body)
      end

      def delete_file(name)
        request = Net::HTTP::Delete.new(URI("https://generativelanguage.googleapis.com/v1beta/#{name}"))
        request["x-goog-api-key"] = api_key
        transport.call(request)
      rescue ApiTransport::Error
        nil
      end

      def ensure_success!(response, action)
        return if response.is_a?(Net::HTTPSuccess)

        body = parse_body(response.body)
        raise ProviderError, body.dig("error", "message") || "Gemini could not #{action}."
      end

      def parse_body(body)
        JSON.parse(body.presence || "{}")
      rescue JSON::ParserError
        raise ProviderError, "Gemini returned an unreadable response. Please try again."
      end
  end
end
