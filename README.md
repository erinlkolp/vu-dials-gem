# vu_dials

An idiomatic Ruby client for [Streacom VU1 Dials](https://vudials.com/). Ruby
port of the `vudials_client` Python module. Zero runtime dependencies — it uses
only the Ruby standard library.

## Installation

```ruby
# Gemfile
gem "vu_dials"
```

Or install directly:

```bash
gem install vu_dials
```

## Usage

### Controlling dials

```ruby
require "vu_dials"

dial = VuDials::Dial.new(host: "localhost", port: 5340, api_key: "your-api-key")

dial.list_dials                                   # => parsed Hash/Array
dial.info(uid: "590056000650564139323920")
dial.set_value(uid: "5900...", value: 50)         # 0–100
dial.set_color(uid: "5900...", red: 100, green: 0, blue: 0)
dial.set_name(uid: "5900...", name: "CPU Load")
dial.set_background(uid: "5900...", file: "gauge.png")
dial.image_crc(uid: "5900...")
dial.reload_hw_info(uid: "5900...")
dial.set_easing(uid: "5900...", period: 50, step: 5)
dial.set_backlight_easing(uid: "5900...", period: 50, step: 5)
dial.easing_config(uid: "5900...")
```

### Server administration

```ruby
admin = VuDials::Admin.new(host: "localhost", port: 5340, admin_key: "your-admin-key")

admin.provision_dials
admin.list_api_keys
admin.create_api_key(name: "dashboard", dials: ["5900...", "5901..."])
admin.update_api_key(name: "dashboard", target_key: "existing-key", dials: ["5900..."])
admin.remove_api_key(target_key: "old-key")
```

## Return values

Every method returns the server's response parsed from JSON (a `Hash` or
`Array`). An empty body returns `nil`; a non-JSON body returns the raw `String`.

## Errors

All errors inherit from `VuDials::Error`:

- `VuDials::HTTPError` — the server returned 4xx/5xx. Exposes `#status` and `#body`.
- `VuDials::ConnectionError` — the request never completed (connection refused, timeout, DNS).

```ruby
begin
  dial.set_value(uid: "5900...", value: 50)
rescue VuDials::HTTPError => e
  warn "server said #{e.status}: #{e.body}"
rescue VuDials::ConnectionError => e
  warn "could not reach the server: #{e.message}"
end
```

## Security notes

These are properties of the upstream VU1 server API, retained deliberately:

- **Plain HTTP only.** No HTTPS support. Keep the server on a trusted local
  interface.
- **Key-in-URL authentication.** The API/admin key travels as a query
  parameter and will appear in server access and proxy logs.
- **No input validation.** The library does not range-check values (e.g. RGB
  0–100) or UID formats; the server is responsible for that.

## Development

```bash
bundle install
bundle exec rake        # run the test suite
```

## License

MIT. See [LICENSE](LICENSE).
