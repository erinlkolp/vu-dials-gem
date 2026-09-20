# frozen_string_literal: true

module VuDials
  # Controls individual VU1 dials: value, backlight color, background image,
  # name, and easing. Every method returns the parsed server response.
  class Dial < Client
    def initialize(host:, port:, api_key:, timeout: 10)
      super(host: host, port: port, key: api_key, timeout: timeout)
    end

    def list_dials
      request(:get, "dial/list")
    end

    def info(uid:)
      request(:get, "dial/#{encode_uid(uid)}/status")
    end

    def set_value(uid:, value:)
      raise ArgumentError, "value cannot be nil" if value.nil?

      request(:get, "dial/#{encode_uid(uid)}/set", query: { "value" => value.to_i })
    end

    def set_color(uid:, red:, green:, blue:)
      raise ArgumentError, "red, green, and blue cannot be nil" if red.nil? || green.nil? || blue.nil?

      request(:get, "dial/#{encode_uid(uid)}/backlight",
              query: { "red" => red.to_i, "green" => green.to_i, "blue" => blue.to_i })
    end

    def set_background(uid:, file:)
      request(:post, "dial/#{encode_uid(uid)}/image/set", file: file)
    end

    def image_crc(uid:)
      request(:get, "dial/#{encode_uid(uid)}/image/crc")
    end

    def set_name(uid:, name:)
      request(:get, "dial/#{encode_uid(uid)}/name", query: { "name" => name })
    end

    def reload_hw_info(uid:)
      request(:get, "dial/#{encode_uid(uid)}/reload")
    end

    def set_easing(uid:, period: nil, step: nil)
      raise ArgumentError, "At least one of period or step must be provided" if period.nil? && step.nil?

      query = {}
      query["period"] = period.to_i unless period.nil?
      query["step"] = step.to_i unless step.nil?

      request(:get, "dial/#{encode_uid(uid)}/easing/dial", query: query)
    end

    def set_backlight_easing(uid:, period: nil, step: nil)
      raise ArgumentError, "At least one of period or step must be provided" if period.nil? && step.nil?

      query = {}
      query["period"] = period.to_i unless period.nil?
      query["step"] = step.to_i unless step.nil?

      request(:get, "dial/#{encode_uid(uid)}/easing/backlight", query: query)
    end

    def easing_config(uid:)
      request(:get, "dial/#{encode_uid(uid)}/easing/get")
    end

    private

    def encode_uid(uid)
      CGI.escape(uid.to_s).gsub("+", "%20")
    end

    def auth_param
      "key"
    end
  end
end
