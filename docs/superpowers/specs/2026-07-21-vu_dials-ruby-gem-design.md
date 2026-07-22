# Design: `vu_dials` Ruby gem

**Date:** 2026-07-21
**Status:** Approved
**Source:** Port of the Python module at `~/workspace/vu1-dial-python-module`
(`vudials_client`, calendar version `2026.7.1`).

## Purpose

Provide an idiomatic Ruby client library for Streacom's VU1 Dial hardware,
functionally equivalent to the existing Python `vudials_client` module. The
library talks to a local VU1 server over plain HTTP using a key-in-URL
query-parameter authentication scheme.

## Decisions (from brainstorming)

- **API style:** Fully idiomatic Ruby — keyword arguments, `snake_case`
  methods, parsed JSON return values, custom error hierarchy.
- **HTTP backend:** `Net::HTTP` from the standard library — zero runtime
  dependencies.
- **Test framework:** RSpec + WebMock (the direct analog of Python's pytest +
  `responses`).
- **Gem name:** `vu_dials`; top-level module `VuDials`; classes `Dial` and
  `Admin`.
- **Version:** Start fresh at `0.1.0` (SemVer). The Python calendar version is
  not carried over.

## Architecture

The two Python utility base classes (`VUUtil`, `VUAdminUtil`) differ only in the
auth query-parameter name (`key=` vs `admin_key=`) and in how they choose the
HTTP verb. They collapse into a single base `VuDials::Client` whose subclasses
configure the auth-param name.

```
vu_dials/
├── lib/
│   ├── vu_dials.rb              # entry point: requires + VuDials namespace
│   └── vu_dials/
│       ├── version.rb           # VuDials::VERSION = "0.1.0"
│       ├── errors.rb            # Error, HTTPError, ConnectionError
│       ├── client.rb            # base: URI building, Net::HTTP dispatch, JSON, raising
│       ├── dial.rb              # VuDials::Dial  (auth param "key")
│       └── admin.rb             # VuDials::Admin (auth param "admin_key")
├── spec/
│   ├── spec_helper.rb           # RSpec + WebMock setup
│   └── vu_dials/
│       ├── client_spec.rb
│       ├── dial_spec.rb
│       └── admin_spec.rb
├── vu_dials.gemspec
├── Gemfile
├── Rakefile                     # default task runs rspec
├── .rspec
├── README.md
├── LICENSE                      # MIT, carried over
└── CHANGELOG.md
```

### `VuDials::Client` (base)

Responsibilities:

- `initialize(host:, port:, api_key:, timeout: 10)` — stores
  `server_url = "http://#{host}:#{port}"`, the key, and the timeout. The
  auth-param name is provided by each subclass (e.g. via a constant or an
  overridable method), defaulting to `"key"`.
- **URI building** — construct
  `#{server_url}/api/v0/#{api_call}?#{auth_param}=#{escaped_key}&...` with all
  user-supplied path segments and query values URL-encoded via `CGI.escape`
  (the port of `urllib.parse.quote(..., safe="")`).
- **Dispatch** — a `request` helper that issues a `Net::HTTP` GET, POST, or
  multipart POST (file upload) with the configured timeout.
- **Error mapping** — check the response status; raise `VuDials::HTTPError` on
  4xx/5xx (the port of `raise_for_status()`); wrap connection/timeout failures
  in `VuDials::ConnectionError`.
- **Return** — parse the response body as JSON and return a `Hash`/`Array`;
  empty body → `nil`; non-JSON body → the raw `String`.

`VuDials::Dial < VuDials::Client` uses auth param `"key"`.
`VuDials::Admin < VuDials::Client` uses auth param `"admin_key"` and its
constructor takes `admin_key:` instead of `api_key:`.

## Public API

Constructors:

```ruby
dial  = VuDials::Dial.new(host: "localhost", port: 5340, api_key: "key")
admin = VuDials::Admin.new(host: "localhost", port: 5340, admin_key: "adminkey")
```

### `VuDials::Dial` (from Python `VUDial`)

| Ruby method | Python origin | HTTP |
|---|---|---|
| `list_dials` | `list_dials` | GET `dial/list` |
| `info(uid:)` | `get_dial_info` | GET `dial/{uid}/status` |
| `set_value(uid:, value:)` | `set_dial_value` | GET `dial/{uid}/set?value=` |
| `set_color(uid:, red:, green:, blue:)` | `set_dial_color` | GET `dial/{uid}/backlight?red=&green=&blue=` |
| `set_background(uid:, file:)` | `set_dial_background` | multipart POST `dial/{uid}/image/set` (`imgfile`) |
| `image_crc(uid:)` | `get_dial_image_crc` | GET `dial/{uid}/image/crc` |
| `set_name(uid:, name:)` | `set_dial_name` | GET `dial/{uid}/name?name=` |
| `reload_hw_info(uid:)` | `reload_hw_info` | GET `dial/{uid}/reload` |
| `set_easing(uid:, period:, step:)` | `set_dial_easing` | GET `dial/{uid}/easing/dial?period=&step=` |
| `set_backlight_easing(uid:, period:, step:)` | `set_backlight_easing` | GET `dial/{uid}/easing/backlight?period=&step=` |
| `easing_config(uid:)` | `get_easing_config` | GET `dial/{uid}/easing/get` |

### `VuDials::Admin` (from Python `VUAdmin`)

| Ruby method | Python origin | HTTP |
|---|---|---|
| `provision_dials` | `provision_dials` | GET `dial/provision` |
| `list_api_keys` | `list_api_keys` | GET `admin/keys/list` |
| `remove_api_key(target_key:)` | `remove_api_key` | GET `admin/keys/remove?key=` |
| `create_api_key(name:, dials:)` | `create_api_key` | POST `admin/keys/create?name=&dials=` |
| `update_api_key(name:, target_key:, dials:)` | `update_api_key` | POST `admin/keys/update?key=&name=&dials=` |

`dials:` is an array of UID strings; joined with `;` and URL-encoded, matching
the Python `";".join(dials)`.

## Return values & errors

- **Success** → parsed JSON (`Hash`/`Array`); empty body → `nil`; non-JSON →
  raw `String`.
- **HTTP 4xx/5xx** → `VuDials::HTTPError` carrying `.status` (Integer) and
  `.body` (String).
- **Network failure** (connection refused, timeout, DNS, etc.) →
  `VuDials::ConnectionError`.
- Hierarchy: `VuDials::Error < StandardError`; both `HTTPError` and
  `ConnectionError` inherit from `VuDials::Error`, so callers can
  `rescue VuDials::Error`.

## Preserved design constraints

Carried over verbatim from the Python module's documented constraints — these
are properties of the upstream VU1 server API and must NOT be silently "fixed":

1. **Plain HTTP only.** No HTTPS. Documented as intentional; server is expected
   on a trusted local interface.
2. **Key-in-URL authentication.** Both `key=` and `admin_key=` appear in the
   query string. Documented caveat retained.
3. **No input validation.** The library does not validate value ranges (RGB
   0–100) or UID format — that is the server's responsibility. Numeric params
   are coerced with `.to_i`, mirroring Python's `int()`.
4. **URL-encoding for injection safety.** All user-supplied path segments
   (`uid`) and query values are escaped with `CGI.escape`, the port of
   `urllib.parse.quote`. A key containing `&`/`=`/`/` must not break query
   structure.

## Testing

RSpec + WebMock, porting the ~40 existing pytest cases. For each public method:

- **Success path** — returns parsed body.
- **Correct endpoint** — request hits the expected path.
- **Correct params** — query/body carries the expected values.
- **URL-encoding / injection safety** — special characters in `uid`, keys, and
  names are escaped and cannot alter query structure.
- **HTTP-error propagation** — 4xx/5xx raises `VuDials::HTTPError`.

Base `Client` gets dedicated specs for URI construction, verb selection
(GET vs multipart POST), timeout handling, and error/return mapping.

The `Rakefile` default task runs the suite; it must be green before the work is
considered complete.

## Out of scope

- Retry/backoff logic, connection pooling, async.
- HTTPS or header-based auth (upstream server does not support these).
- A CLI wrapper.
- Publishing to RubyGems (the gem will be build-ready but not pushed).
