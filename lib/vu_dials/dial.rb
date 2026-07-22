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
      request(:get, "dial/#{CGI.escape(uid)}/status")
    end

    def set_value(uid:, value:)
      request(:get, "dial/#{CGI.escape(uid)}/set", query: { "value" => value.to_i })
    end

    def set_color(uid:, red:, green:, blue:)
      request(:get, "dial/#{CGI.escape(uid)}/backlight",
              query: { "red" => red.to_i, "green" => green.to_i, "blue" => blue.to_i })
    end

    def set_background(uid:, file:)
      request(:post, "dial/#{CGI.escape(uid)}/image/set", file: file)
    end

    def image_crc(uid:)
      request(:get, "dial/#{CGI.escape(uid)}/image/crc")
    end

    def set_name(uid:, name:)
      request(:get, "dial/#{CGI.escape(uid)}/name", query: { "name" => name })
    end

    def reload_hw_info(uid:)
      request(:get, "dial/#{CGI.escape(uid)}/reload")
    end

    def set_easing(uid:, period:, step:)
      request(:get, "dial/#{CGI.escape(uid)}/easing/dial",
              query: { "period" => period.to_i, "step" => step.to_i })
    end

    def set_backlight_easing(uid:, period:, step:)
      request(:get, "dial/#{CGI.escape(uid)}/easing/backlight",
              query: { "period" => period.to_i, "step" => step.to_i })
    end

    def easing_config(uid:)
      request(:get, "dial/#{CGI.escape(uid)}/easing/get")
    end

    private

    def auth_param
      "key"
    end
  end
end
