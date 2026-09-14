require "net/http"

class ApiTransport
  class Error < StandardError; end
  class ConnectionError < Error; end

  def initialize(client: Net::HTTP, open_timeout: 5, read_timeout: 15)
    @client = client
    @open_timeout = open_timeout
    @read_timeout = read_timeout
  end

  def call(request)
    uri = request.uri
    http = @client.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout
    http.request(request)
  rescue IOError, SocketError, SystemCallError, Timeout::Error => error
    raise ConnectionError, error.message
  end
end
