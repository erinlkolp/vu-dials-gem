# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"
require "timeout"
require "uri"

module VuDials
  # Base class shared by Dial and Admin. Builds request URIs with the
  # correct auth query parameter and URL-encodes all supplied values.
  #
  # Not meant to be instantiated directly; subclasses must define #auth_param.
  class Client
    API_PREFIX = "api/v0"

    def initialize(host:, port:, key:, timeout: 10)
      @server_url = "http://#{host}:#{port}"
      @key = key
      @timeout = timeout
    end

    private

    # Subclasses return "key" (Dial) or "admin_key" (Admin).
    def auth_param
      raise NotImplementedError, "#{self.class} must define #auth_param"
    end

    # Security note: the auth key is transmitted as a URL query parameter, so
    # it appears in server access and proxy logs. This is intentional; the VU1
    # server only supports key-in-URL auth over plain HTTP.
    def build_uri(api_call, query = {})
      params = { auth_param => @key }.merge(query).compact
      encoded = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
      URI("#{@server_url}/#{API_PREFIX}/#{api_call}?#{encoded}")
    end

    def request(method, api_call, query: {}, file: nil)
      uri = build_uri(api_call, query)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http.write_timeout = @timeout if http.respond_to?(:write_timeout=)

      req =
        case method
        when :get
          Net::HTTP::Get.new(uri)
        when :post
          build_post(uri, file)
        else
          raise ArgumentError, "Unsupported HTTP method: #{method.inspect}"
        end

      response =
        begin
          http.request(req)
        rescue SocketError, SystemCallError, Timeout::Error, Net::ProtocolError, IOError => e
          raise ConnectionError, e.message
        end

      handle_response(response)
    end

    # Builds the multipart body by hand (rather than Net::HTTP's
    # set_form(..., "multipart/form-data")): set_form defers encoding to
    # HTTPGenericRequest#exec via an internal @body_data ivar that only real
    # socket I/O reads, so WebMock (which intercepts before #exec) never sees
    # a body to stub against. Setting req.body directly keeps this testable.
    def build_post(uri, file)
      req = Net::HTTP::Post.new(uri)
      if file
        boundary = "----VuDialsFormBoundary#{rand(1_000_000_000_000)}"
        req.body = multipart_body(file, boundary)
        req.content_type = "multipart/form-data; boundary=#{boundary}"
      end
      req
    end

    def multipart_body(file, boundary)
      filename = File.basename(file).gsub(/["\r\n]/, "").b
      data = File.binread(file)
      +"--#{boundary}\r\n" \
        "Content-Disposition: form-data; name=\"imgfile\"; filename=\"#{filename}\"\r\n" \
        "Content-Type: application/octet-stream\r\n\r\n" \
        "#{data}\r\n" \
        "--#{boundary}--\r\n"
    end

    # Port of Python's raise_for_status(): raise on 4xx/5xx, otherwise parse.
    def handle_response(response)
      status = response.code.to_i
      raise HTTPError.new(status: status, body: response.body.to_s) if status >= 400

      parse_body(response.body)
    end

    def parse_body(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end
  end
end
