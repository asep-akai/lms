require "test_helper"

class Ai::GeminiClientTest < ActiveSupport::TestCase
  class FakeTransport
    attr_reader :request

    def initialize(response)
      @response = response
    end

    def call(request)
      @request = request
      @response
    end
  end

  test "requests structured JSON without placing the API key in the URL" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, {
      responseId: "gemini-response",
      candidates: [ { content: { parts: [ { text: '{"analysis":"Useful"}' } ] } } ]
    }.to_json)
    response.instance_variable_set(:@read, true)
    transport = FakeTransport.new(response)
    client = Ai::GeminiClient.new(api_key: "secret-key", model: "gemini-test", transport: transport)

    result = client.generate_json(
      system_instruction: "Analyze.",
      prompt: "Quiz data",
      schema: { type: "object", properties: { analysis: { type: "string" } } }
    )

    assert_equal({ "analysis" => "Useful" }, result.data)
    assert_equal "gemini-response", result.response_id
    assert_equal "secret-key", transport.request["x-goog-api-key"]
    assert_nil transport.request.uri.query
    assert_equal "application/json", JSON.parse(transport.request.body).dig("generationConfig", "responseMimeType")
  end

  test "explains how to configure a missing API key" do
    client = Ai::GeminiClient.new(api_key: "", model: "gemini-test", transport: Object.new)

    error = assert_raises(Ai::ConfigurationError) do
      client.generate_json(system_instruction: "Analyze.", prompt: "Quiz data", schema: {})
    end

    assert_match "GEMINI_API_KEY", error.message
  end
end
