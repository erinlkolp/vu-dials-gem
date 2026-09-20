# frozen_string_literal: true

module VuDials
  # Manages the VU1 server: dial provisioning and API key lifecycle.
  # Every method returns the parsed server response.
  class Admin < Client
    def initialize(host:, port:, admin_key:, timeout: 10)
      super(host: host, port: port, key: admin_key, timeout: timeout)
    end

    def provision_dials
      request(:get, "dial/provision")
    end

    def list_api_keys
      request(:get, "admin/keys/list")
    end

    def remove_api_key(target_key:)
      request(:get, "admin/keys/remove", query: { "key" => target_key })
    end

    def create_api_key(name:, dials:)
      request(:post, "admin/keys/create",
              query: { "name" => name, "dials" => dials.join(";") })
    end

    def update_api_key(target_key:, name: nil, dials: nil)
      raise ArgumentError, "At least one of name or dials must be provided" if name.nil? && dials.nil?

      query = { "key" => target_key }
      query["name"] = name unless name.nil?
      query["dials"] = Array(dials).join(";") unless dials.nil?

      request(:post, "admin/keys/update", query: query)
    end

    private

    def auth_param
      "admin_key"
    end
  end
end
