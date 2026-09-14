require "test_helper"

class ApiTransportTest < ActiveSupport::TestCase
  class FakeConnection
    attr_accessor :use_ssl, :open_timeout, :read_timeout
    attr_reader :last_request

    def initialize(response)
      @response = response
    end

    def request(request)
      @last_request = request
      @response
    end
  end

  test "applies timeouts and returns the client response" do
    response = Object.new
    connection = FakeConnection.new(response)
    client = Object.new
    client.define_singleton_method(:new) { |_host, _port| connection }
    request = Net::HTTP::Get.new(URI("https://example.test/health"))

    result = ApiTransport.new(client: client, open_timeout: 2, read_timeout: 9).call(request)

    assert_same response, result
    assert connection.use_ssl
    assert_equal 2, connection.open_timeout
    assert_equal 9, connection.read_timeout
    assert_same request, connection.last_request
  end

  test "wraps network failures" do
    client = Object.new
    client.define_singleton_method(:new) { |_host, _port| raise SocketError, "offline" }
    request = Net::HTTP::Get.new(URI("https://example.test/health"))

    assert_raises(ApiTransport::ConnectionError) { ApiTransport.new(client: client).call(request) }
  end
end
