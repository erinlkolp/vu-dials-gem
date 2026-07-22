# frozen_string_literal: true

module VuDials
  # Base class for every error raised by this library.
  class Error < StandardError; end

  # Raised when the VU1 server responds with an HTTP 4xx or 5xx status.
  class HTTPError < Error
    attr_reader :status, :body

    def initialize(status:, body:)
      @status = status
      @body = body
      super("HTTP #{status}: #{body}")
    end
  end

  # Raised when the request never reaches a valid HTTP response
  # (connection refused, timeout, DNS failure, etc.).
  class ConnectionError < Error; end
end
