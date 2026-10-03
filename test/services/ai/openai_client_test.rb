require "test_helper"

class Ai::OpenaiClientTest < ActiveSupport::TestCase
  class FakeTransport
    attr_reader :requests

    def initialize(*responses)
      @responses = responses
      @requests = []
    end

    def call(request)
      @requests << request
      @responses.shift || raise("Missing fake response")
    end
  end

  test "requests strict structured JSON without placing the API key in the URL" do
    transport = FakeTransport.new(http_response(
      id: "response-123",
      output: [ { type: "message", content: [ { type: "output_text", text: '{"analysis":"Useful"}' } ] } ]
    ))
    client = Ai::OpenaiClient.new(api_key: "secret-key", model: "openai-test", transport:)

    result = client.generate_json(
      system_instruction: "Analyze.",
      prompt: "Quiz data",
      schema: { type: "object", properties: { analysis: { type: "string" } }, required: [ "analysis" ] }
    )

    request = transport.requests.first
    payload = JSON.parse(request.body)
    assert_equal({ "analysis" => "Useful" }, result.data)
    assert_equal "response-123", result.response_id
    assert_equal "Bearer secret-key", request["Authorization"]
    assert_nil request.uri.query
    assert_equal false, payload.fetch("store")
    assert_equal "json_schema", payload.dig("text", "format", "type")
    assert_equal true, payload.dig("text", "format", "strict")
    assert_equal false, payload.dig("text", "format", "schema", "additionalProperties")
  end

  test "explains how to configure a missing API key" do
    client = Ai::OpenaiClient.new(api_key: "", model: "openai-test", transport: Object.new)

    error = assert_raises(Ai::ConfigurationError) do
      client.generate_json(system_instruction: "Analyze.", prompt: "Quiz data", schema: {})
    end

    assert_match "OPENAI_API_KEY", error.message
  end

  test "adds labelled inline images to a Responses API request" do
    transport = FakeTransport.new(http_response(
      output: [ { type: "message", content: [ { type: "output_text", text: '{"analysis":"Useful"}' } ] } ]
    ))
    client = Ai::OpenaiClient.new(api_key: "secret-key", model: "openai-test", transport:)
    media = Ai::OpenaiClient::Media.new(label: "page-image-1", mime_type: "image/png", data: "image bytes", display_name: "source.png")

    client.generate_json(
      system_instruction: "Analyze.",
      prompt: "Quiz data",
      schema: { type: "object", properties: { analysis: { type: "string" } } },
      media: [ media ]
    )

    content = JSON.parse(transport.requests.first.body).dig("input", 0, "content")
    assert_equal "Quiz data", content.first.fetch("text")
    assert_equal "Media label: page-image-1", content.second.fetch("text")
    assert_equal "input_image", content.third.fetch("type")
    assert_equal "data:image/png;base64,#{Base64.strict_encode64('image bytes')}", content.third.fetch("image_url")
  end

  test "transcribes audio before analysis and preserves the exact transcript" do
    transport = FakeTransport.new(
      http_response(text: "A faithful spoken response."),
      http_response(
        id: "response-audio",
        output: [ {
          type: "message",
          content: [ {
            type: "output_text",
            text: '{"analysis":"Useful","transcriptions":[{"question_id":7,"text":"Changed"}]}'
          } ]
        } ]
      )
    )
    client = Ai::OpenaiClient.new(
      api_key: "secret-key",
      model: "openai-test",
      transcription_model: "transcribe-test",
      transport:
    )
    media = Ai::OpenaiClient::Media.new(
      label: "question-7-student-audio",
      mime_type: "audio/mpeg",
      data: "ID3 audio bytes",
      display_name: "response.mp3"
    )

    result = client.generate_json(
      system_instruction: "Analyze.",
      prompt: "Quiz data",
      schema: { type: "object", properties: { analysis: { type: "string" }, transcriptions: { type: "array" } } },
      media: [ media ]
    )

    transcription_request, response_request = transport.requests
    assert_equal URI(Ai::OpenaiClient::TRANSCRIPTIONS_ENDPOINT), transcription_request.uri
    assert_includes transcription_request["Content-Type"], "multipart/form-data"
    assert_includes transcription_request.body, "transcribe-test"
    assert_includes transcription_request.body, "response.mp3"
    assert_includes transcription_request.body, "ID3 audio bytes"
    content = JSON.parse(response_request.body).dig("input", 0, "content")
    assert_equal "Faithful audio transcript: A faithful spoken response.", content.last.fetch("text")
    assert_equal [ { "question_id" => 7, "text" => "A faithful spoken response." } ], result.data.fetch("transcriptions")
  end

  private
    def http_response(**body)
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@body, body.to_json)
      response.instance_variable_set(:@read, true)
      response
    end
end
