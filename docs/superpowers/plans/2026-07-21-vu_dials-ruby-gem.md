# vu_dials Ruby Gem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `vu_dials`, an idiomatic, zero-dependency Ruby gem that ports the Python `vudials_client` module — a client for Streacom VU1 Dial hardware.

**Architecture:** A base `VuDials::Client` handles URI construction (with URL-encoding), `Net::HTTP` dispatch (GET / multipart POST), JSON parsing, and error mapping. Two subclasses, `VuDials::Dial` and `VuDials::Admin`, expose the public methods; they differ only in the auth query-param name (`key` vs `admin_key`), supplied by overriding a private `auth_param` method.

**Tech Stack:** Ruby 3.2 (gem targets `>= 3.0`), `Net::HTTP` + `json` + `cgi` (all stdlib), RSpec + WebMock for tests, Rake for the default task.

## Global Constraints

- **Zero runtime dependencies.** Only stdlib (`net/http`, `uri`, `cgi`, `json`) at runtime. RSpec/WebMock/Rake are development dependencies only.
- **Gem name `vu_dials`; module `VuDials`; classes `Dial`, `Admin`.**
- **Version `0.1.0`** (SemVer), defined once in `lib/vu_dials/version.rb`.
- **`required_ruby_version >= 3.0`.**
- **Keyword arguments** on every public method and constructor.
- **URL-encode** every user-supplied path segment (`uid`) and every query value with `CGI.escape`. A key/uid/name containing `&`, `=`, or `/` must never alter query-string structure.
- **No value-range validation** (RGB, UID format). Coerce numeric params with `.to_i` (the port of Python `int()`). Do not add validation.
- **Plain HTTP only, key-in-URL auth** — intentional; document, do not "fix".
- **Return** parsed JSON (`Hash`/`Array`); empty body → `nil`; non-JSON body → raw `String`.
- **Errors:** `VuDials::Error < StandardError`; `HTTPError` (with `.status`, `.body`) and `ConnectionError` both inherit from `Error`. HTTP 4xx/5xx → `HTTPError`; connection/timeout → `ConnectionError`.
- **Author metadata:** Erin L. Kolp <erinlkolpfoss@gmail.com>, MIT license, homepage `https://github.com/erinlkolp/vu1-dial-python-module`.
- All commands run from the gem root (`/home/ekolp/workspace/ruby-first-steps`). Tests run with `bundle exec rspec`; the full suite with `bundle exec rake`.

---

## File Structure

- `vu_dials.gemspec` — gem metadata, dev dependencies.
- `Gemfile` — `gemspec` directive.
- `Rakefile` — default task runs RSpec.
- `.rspec` — loads `spec_helper`.
- `.gitignore` — standard Ruby ignores.
- `LICENSE` — MIT (carried over).
- `CHANGELOG.md` — `0.1.0` entry.
- `README.md` — usage docs.
- `lib/vu_dials.rb` — entry point; requires all components.
- `lib/vu_dials/version.rb` — `VuDials::VERSION`.
- `lib/vu_dials/errors.rb` — error hierarchy.
- `lib/vu_dials/client.rb` — base client: `build_uri`, `request`, response handling.
- `lib/vu_dials/dial.rb` — `VuDials::Dial` (11 methods, auth param `"key"`).
- `lib/vu_dials/admin.rb` — `VuDials::Admin` (5 methods, auth param `"admin_key"`).
- `spec/spec_helper.rb` — RSpec + WebMock config.
- `spec/vu_dials/version_spec.rb`, `errors_spec.rb`, `client_spec.rb`, `dial_spec.rb`, `admin_spec.rb`.

---

## Task 1: Gem scaffold, version, errors, test harness

Establishes a buildable gem with a green test run. Folds in all boilerplate (gemspec, Gemfile, Rakefile, .rspec, .gitignore, LICENSE, CHANGELOG) because nothing can be tested until the harness loads.

**Files:**
- Create: `vu_dials.gemspec`, `Gemfile`, `Rakefile`, `.rspec`, `.gitignore`, `LICENSE`, `CHANGELOG.md`
- Create: `lib/vu_dials/version.rb`, `lib/vu_dials/errors.rb`, `lib/vu_dials.rb`
- Create: `spec/spec_helper.rb`
- Test: `spec/vu_dials/version_spec.rb`, `spec/vu_dials/errors_spec.rb`

**Interfaces:**
- Produces: `VuDials::VERSION` (String); `VuDials::Error < StandardError`; `VuDials::HTTPError.new(status:, body:)` with readers `#status` (Integer), `#body` (String); `VuDials::ConnectionError < VuDials::Error`.

- [ ] **Step 1: Create the gemspec**

Create `vu_dials.gemspec`:

```ruby
# frozen_string_literal: true

require_relative "lib/vu_dials/version"

Gem::Specification.new do |spec|
  spec.name = "vu_dials"
  spec.version = VuDials::VERSION
  spec.authors = ["Erin L. Kolp"]
  spec.email = ["erinlkolpfoss@gmail.com"]

  spec.summary = "Ruby client for Streacom VU1 Dials"
  spec.description = "An idiomatic Ruby client library for Streacom's VU1 Dial " \
                     "hardware, communicating with a local VU1 server over HTTP."
  spec.homepage = "https://github.com/erinlkolp/vu1-dial-python-module"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*.rb"] + ["README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
```

- [ ] **Step 2: Create Gemfile, Rakefile, .rspec, .gitignore**

`Gemfile`:

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec
```

`Rakefile`:

```ruby
# frozen_string_literal: true

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec
```

`.rspec`:

```
--require spec_helper
--format documentation
```

`.gitignore`:

```
/.bundle/
/pkg/
/tmp/
/coverage/
*.gem
Gemfile.lock
```

- [ ] **Step 3: Create LICENSE and CHANGELOG.md**

`LICENSE` (MIT):

```
MIT License

Copyright (c) 2026 Erin L. Kolp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

`CHANGELOG.md`:

```markdown
# Changelog

## [0.1.0] - 2026-07-21

### Added
- Initial release. Ruby port of the `vudials_client` Python module.
- `VuDials::Dial` — dial control (value, color, background image, name, easing).
- `VuDials::Admin` — server admin (dial provisioning, API key lifecycle).
- Error hierarchy: `VuDials::Error`, `HTTPError`, `ConnectionError`.
```

- [ ] **Step 4: Create version, errors, and entry point**

`lib/vu_dials/version.rb`:

```ruby
# frozen_string_literal: true

module VuDials
  VERSION = "0.1.0"
end
```

`lib/vu_dials/errors.rb`:

```ruby
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
```

`lib/vu_dials.rb`:

```ruby
# frozen_string_literal: true

require "vu_dials/version"
require "vu_dials/errors"
require "vu_dials/client"
require "vu_dials/dial"
require "vu_dials/admin"

module VuDials
end
```

- [ ] **Step 5: Create spec_helper**

`spec/spec_helper.rb`:

```ruby
# frozen_string_literal: true

require "vu_dials"
require "webmock/rspec"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
end
```

- [ ] **Step 6: Write the failing tests**

`spec/vu_dials/version_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe "VuDials::VERSION" do
  it "is a SemVer string" do
    expect(VuDials::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
```

`spec/vu_dials/errors_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe VuDials::HTTPError do
  it "inherits from VuDials::Error" do
    expect(described_class.ancestors).to include(VuDials::Error)
  end

  it "exposes status and body" do
    error = described_class.new(status: 404, body: "not found")
    expect(error.status).to eq(404)
    expect(error.body).to eq("not found")
  end

  it "builds a descriptive message" do
    error = described_class.new(status: 500, body: "boom")
    expect(error.message).to eq("HTTP 500: boom")
  end
end

RSpec.describe VuDials::ConnectionError do
  it "inherits from VuDials::Error" do
    expect(described_class.ancestors).to include(VuDials::Error)
  end
end
```

Note: `lib/vu_dials.rb` requires `vu_dials/client`, `dial`, and `admin`, which do not exist yet — the suite will fail to load. That is the expected failure for this step.

- [ ] **Step 7: Run tests to verify they fail**

Run: `bundle install && bundle exec rspec spec/vu_dials/version_spec.rb spec/vu_dials/errors_spec.rb`
Expected: FAIL — `LoadError: cannot load such file -- vu_dials/client`.

- [ ] **Step 8: Make the suite loadable**

Temporarily comment out the client/dial/admin requires so the harness proves green with only version + errors. In `lib/vu_dials.rb`, comment the three lines:

```ruby
# frozen_string_literal: true

require "vu_dials/version"
require "vu_dials/errors"
# require "vu_dials/client"
# require "vu_dials/dial"
# require "vu_dials/admin"

module VuDials
end
```

(These three requires get uncommented in Tasks 3, 4, and 5 as each file is created.)

- [ ] **Step 9: Run tests to verify they pass**

Run: `bundle exec rspec spec/vu_dials/version_spec.rb spec/vu_dials/errors_spec.rb`
Expected: PASS — 5 examples, 0 failures.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: scaffold vu_dials gem with version and error hierarchy"
```

---

## Task 2: Client base — URI construction

Builds the request URI with the auth param and URL-encoded values. Tested through the concrete `Dial` and `Admin` subclasses because `build_uri` depends on the subclass `auth_param`.

**Files:**
- Create: `lib/vu_dials/client.rb` (partial — constructor + `build_uri` + `auth_param` hook)
- Test: `spec/vu_dials/client_spec.rb` (URI construction section)

**Interfaces:**
- Consumes: nothing from earlier tasks beyond the error classes.
- Produces: `VuDials::Client` with `initialize(host:, port:, key:, timeout: 10)`; private `build_uri(api_call, query = {})` returning a `URI` whose string is `http://HOST:PORT/api/v0/API_CALL?AUTH_PARAM=KEY[&k=v...]`; private `auth_param` raising `NotImplementedError` in the base. Subclasses define `auth_param`. For test purposes, this task also defines minimal `VuDials::Dial`/`VuDials::Admin` stubs — but those get fully implemented in Tasks 4–5, so to avoid rework this task tests via two throwaway subclasses defined inline in the spec.

- [ ] **Step 1: Write the failing test**

`spec/vu_dials/client_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe VuDials::Client do
  # Concrete subclasses for exercising the abstract base.
  let(:key_client) do
    Class.new(described_class) do
      private def auth_param = "key"
    end.new(host: "localhost", port: 5340, key: "mykey")
  end

  let(:admin_client) do
    Class.new(described_class) do
      private def auth_param = "admin_key"
    end.new(host: "localhost", port: 5340, key: "adminkey")
  end

  describe "#build_uri" do
    it "builds the api/v0 path with the key query param" do
      uri = key_client.send(:build_uri, "dial/list")
      expect(uri.to_s).to eq("http://localhost:5340/api/v0/dial/list?key=mykey")
    end

    it "appends query params after the key" do
      uri = key_client.send(:build_uri, "dial/abc/set", { "value" => 50 })
      expect(uri.to_s).to eq("http://localhost:5340/api/v0/dial/abc/set?key=mykey&value=50")
    end

    it "uses admin_key for the admin subclass" do
      uri = admin_client.send(:build_uri, "admin/keys/list")
      expect(uri.to_s).to eq("http://localhost:5340/api/v0/admin/keys/list?admin_key=adminkey")
    end

    it "URL-encodes a key containing & and = so it cannot inject params" do
      client = Class.new(described_class) do
        private def auth_param = "key"
      end.new(host: "localhost", port: 5340, key: "k&admin_key=evil")
      uri = client.send(:build_uri, "dial/list")
      expect(uri.to_s).to include("k%26admin_key%3Devil")
      expect(uri.to_s).not_to include("admin_key=evil")
    end

    it "URL-encodes query values" do
      uri = key_client.send(:build_uri, "dial/abc/name", { "name" => "a&b=c" })
      expect(uri.to_s).to include("name=a%26b%3Dc")
    end

    it "raises NotImplementedError when the base class is used directly" do
      base = described_class.new(host: "localhost", port: 5340, key: "k")
      expect { base.send(:build_uri, "dial/list") }.to raise_error(NotImplementedError)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/vu_dials/client_spec.rb`
Expected: FAIL — `LoadError` / `uninitialized constant VuDials::Client`.

- [ ] **Step 3: Write minimal implementation**

`lib/vu_dials/client.rb`:

```ruby
# frozen_string_literal: true

require "cgi"
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
      params = { auth_param => @key }.merge(query)
      encoded = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
      URI("#{@server_url}/#{API_PREFIX}/#{api_call}?#{encoded}")
    end
  end
end
```

Uncomment the client require in `lib/vu_dials.rb`:

```ruby
require "vu_dials/client"
# require "vu_dials/dial"
# require "vu_dials/admin"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/vu_dials/client_spec.rb`
Expected: PASS — 6 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Client base with URI construction and URL-encoding"
```

---

## Task 3: Client base — request dispatch, response handling

Adds `Net::HTTP` dispatch (GET, multipart POST), JSON parsing, HTTP-error raising, and connection-error wrapping.

**Files:**
- Modify: `lib/vu_dials/client.rb` (add `request` and response helpers)
- Test: `spec/vu_dials/client_spec.rb` (add a `#request` describe block)

**Interfaces:**
- Consumes: `build_uri` from Task 2; `HTTPError`, `ConnectionError` from Task 1.
- Produces: private `request(method, api_call, query: {}, file: nil)` where `method` is `:get` or `:post`. Returns parsed JSON (`Hash`/`Array`), `nil` for an empty body, or the raw `String` for non-JSON. Raises `HTTPError` on status >= 400 and `ConnectionError` on transport failures. When `file:` is given (POST only), uploads it as multipart form field `imgfile`.

- [ ] **Step 1: Write the failing test**

Append to `spec/vu_dials/client_spec.rb` (inside the top-level `describe VuDials::Client`):

```ruby
  describe "#request" do
    let(:client) do
      Class.new(described_class) do
        private def auth_param = "key"
      end.new(host: "localhost", port: 5340, key: "mykey")
    end

    it "issues a GET and returns parsed JSON" do
      stub_request(:get, "http://localhost:5340/api/v0/dial/list?key=mykey")
        .to_return(status: 200, body: '{"status":"ok"}')
      expect(client.send(:request, :get, "dial/list")).to eq("status" => "ok")
    end

    it "returns nil for an empty body" do
      stub_request(:get, %r{/api/v0/dial/list}).to_return(status: 200, body: "")
      expect(client.send(:request, :get, "dial/list")).to be_nil
    end

    it "returns the raw string for a non-JSON body" do
      stub_request(:get, %r{/api/v0/dial/list}).to_return(status: 200, body: "plain text")
      expect(client.send(:request, :get, "dial/list")).to eq("plain text")
    end

    it "raises HTTPError with status and body on 404" do
      stub_request(:get, %r{/api/v0/dial/list}).to_return(status: 404, body: "nope")
      expect { client.send(:request, :get, "dial/list") }
        .to raise_error(VuDials::HTTPError) { |e|
          expect(e.status).to eq(404)
          expect(e.body).to eq("nope")
        }
    end

    it "raises HTTPError on 500" do
      stub_request(:get, %r{/api/v0/dial/list}).to_return(status: 500, body: "boom")
      expect { client.send(:request, :get, "dial/list") }.to raise_error(VuDials::HTTPError)
    end

    it "wraps a connection refusal in ConnectionError" do
      stub_request(:get, %r{/api/v0/dial/list}).to_raise(Errno::ECONNREFUSED)
      expect { client.send(:request, :get, "dial/list") }.to raise_error(VuDials::ConnectionError)
    end

    it "wraps a timeout in ConnectionError" do
      stub_request(:get, %r{/api/v0/dial/list}).to_timeout
      expect { client.send(:request, :get, "dial/list") }.to raise_error(VuDials::ConnectionError)
    end

    it "issues a POST when method is :post" do
      stub = stub_request(:post, %r{/api/v0/admin/keys/create}).to_return(status: 200, body: "{}")
      client.send(:request, :post, "admin/keys/create", query: { "name" => "n" })
      expect(stub).to have_been_requested
    end

    it "uploads a file as multipart form field imgfile" do
      require "tempfile"
      file = Tempfile.new(["img", ".png"])
      file.write("fake image data")
      file.close
      stub = stub_request(:post, %r{/api/v0/dial/abc/image/set})
        .with { |req|
          req.headers["Content-Type"].to_s.start_with?("multipart/form-data") &&
            req.body.include?("fake image data") &&
            req.body.include?('name="imgfile"')
        }
        .to_return(status: 200, body: "{}")
      client.send(:request, :post, "dial/abc/image/set", file: file.path)
      expect(stub).to have_been_requested
    ensure
      file&.unlink
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/vu_dials/client_spec.rb -e "#request"`
Expected: FAIL — `NoMethodError` / no such private method `request`.

- [ ] **Step 3: Write minimal implementation**

Add `require "json"` and `require "net/http"` at the top of `lib/vu_dials/client.rb`, then add these private methods below `build_uri`:

```ruby
    def request(method, api_call, query: {}, file: nil)
      uri = build_uri(api_call, query)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      req =
        case method
        when :get
          Net::HTTP::Get.new(uri)
        when :post
          build_post(uri, file)
        else
          raise ArgumentError, "Unsupported HTTP method: #{method.inspect}"
        end

      handle_response(http.request(req))
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError => e
      raise ConnectionError, e.message
    end

    def build_post(uri, file)
      req = Net::HTTP::Post.new(uri)
      if file
        req.set_form(
          [["imgfile", File.read(file), { filename: File.basename(file) }]],
          "multipart/form-data"
        )
      end
      req
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
```

Add the requires at the top (alongside `require "cgi"` / `require "uri"`):

```ruby
require "json"
require "net/http"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/vu_dials/client_spec.rb`
Expected: PASS — 15 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add HTTP dispatch, JSON parsing, and error mapping to Client"
```

---

## Task 4: VuDials::Dial

The eleven dial-control methods.

**Files:**
- Create: `lib/vu_dials/dial.rb`
- Test: `spec/vu_dials/dial_spec.rb`

**Interfaces:**
- Consumes: `VuDials::Client#request` and `#build_uri` from Tasks 2–3.
- Produces: `VuDials::Dial.new(host:, port:, api_key:, timeout: 10)` with public methods `list_dials`, `info(uid:)`, `set_value(uid:, value:)`, `set_color(uid:, red:, green:, blue:)`, `set_background(uid:, file:)`, `image_crc(uid:)`, `set_name(uid:, name:)`, `reload_hw_info(uid:)`, `set_easing(uid:, period:, step:)`, `set_backlight_easing(uid:, period:, step:)`, `easing_config(uid:)`. Auth param `"key"`.

- [ ] **Step 1: Write the failing test**

`spec/vu_dials/dial_spec.rb`:

```ruby
# frozen_string_literal: true

require "tempfile"

RSpec.describe VuDials::Dial do
  let(:dial) { described_class.new(host: "localhost", port: 5340, api_key: "test-api-key") }
  let(:base) { "http://localhost:5340/api/v0" }

  def ok(body = "{}")
    { status: 200, body: body }
  end

  describe "#list_dials" do
    it "GETs dial/list with the api key and returns parsed JSON" do
      stub = stub_request(:get, "#{base}/dial/list").with(query: { "key" => "test-api-key" })
                                                     .to_return(ok('{"status":"ok"}'))
      expect(dial.list_dials).to eq("status" => "ok")
      expect(stub).to have_been_requested
    end

    it "propagates HTTP errors" do
      stub_request(:get, "#{base}/dial/list").to_return(status: 500, body: "boom")
      expect { dial.list_dials }.to raise_error(VuDials::HTTPError)
    end
  end

  describe "#info" do
    it "GETs dial/{uid}/status" do
      stub = stub_request(:get, "#{base}/dial/abc/status").with(query: hash_including("key" => "test-api-key"))
                                                           .to_return(ok)
      dial.info(uid: "abc")
      expect(stub).to have_been_requested
    end

    it "URL-encodes the uid" do
      stub = stub_request(:get, "#{base}/dial/a%26b/status").to_return(ok)
      dial.info(uid: "a&b")
      expect(stub).to have_been_requested
    end
  end

  describe "#set_value" do
    it "GETs dial/{uid}/set with the value" do
      stub = stub_request(:get, "#{base}/dial/abc/set")
             .with(query: { "key" => "test-api-key", "value" => "50" }).to_return(ok)
      dial.set_value(uid: "abc", value: 50)
      expect(stub).to have_been_requested
    end

    it "coerces the value to an integer" do
      stub = stub_request(:get, "#{base}/dial/abc/set")
             .with(query: hash_including("value" => "0")).to_return(ok)
      dial.set_value(uid: "abc", value: 0)
      expect(stub).to have_been_requested
    end
  end

  describe "#set_color" do
    it "GETs dial/{uid}/backlight with red/green/blue" do
      stub = stub_request(:get, "#{base}/dial/abc/backlight")
             .with(query: hash_including("red" => "10", "green" => "20", "blue" => "30"))
             .to_return(ok)
      dial.set_color(uid: "abc", red: 10, green: 20, blue: 30)
      expect(stub).to have_been_requested
    end
  end

  describe "#set_background" do
    it "POSTs the image as multipart to dial/{uid}/image/set" do
      file = Tempfile.new(["img", ".png"])
      file.write("fake image data")
      file.close
      stub = stub_request(:post, "#{base}/dial/abc/image/set")
             .with(query: hash_including("key" => "test-api-key")) { |req|
               req.headers["Content-Type"].to_s.start_with?("multipart/form-data") &&
                 req.body.include?("fake image data")
             }
             .to_return(ok)
      dial.set_background(uid: "abc", file: file.path)
      expect(stub).to have_been_requested
    ensure
      file&.unlink
    end
  end

  describe "#image_crc" do
    it "GETs dial/{uid}/image/crc" do
      stub = stub_request(:get, "#{base}/dial/abc/image/crc").to_return(ok)
      dial.image_crc(uid: "abc")
      expect(stub).to have_been_requested
    end
  end

  describe "#set_name" do
    it "GETs dial/{uid}/name with the URL-encoded name" do
      stub = stub_request(:get, "#{base}/dial/abc/name")
             .with(query: hash_including("name" => "Living Room")).to_return(ok)
      dial.set_name(uid: "abc", name: "Living Room")
      expect(stub).to have_been_requested
    end
  end

  describe "#reload_hw_info" do
    it "GETs dial/{uid}/reload" do
      stub = stub_request(:get, "#{base}/dial/abc/reload").to_return(ok)
      dial.reload_hw_info(uid: "abc")
      expect(stub).to have_been_requested
    end
  end

  describe "#set_easing" do
    it "GETs dial/{uid}/easing/dial with period/step" do
      stub = stub_request(:get, "#{base}/dial/abc/easing/dial")
             .with(query: hash_including("period" => "5", "step" => "2")).to_return(ok)
      dial.set_easing(uid: "abc", period: 5, step: 2)
      expect(stub).to have_been_requested
    end
  end

  describe "#set_backlight_easing" do
    it "GETs dial/{uid}/easing/backlight with period/step" do
      stub = stub_request(:get, "#{base}/dial/abc/easing/backlight")
             .with(query: hash_including("period" => "5", "step" => "2")).to_return(ok)
      dial.set_backlight_easing(uid: "abc", period: 5, step: 2)
      expect(stub).to have_been_requested
    end
  end

  describe "#easing_config" do
    it "GETs dial/{uid}/easing/get" do
      stub = stub_request(:get, "#{base}/dial/abc/easing/get").to_return(ok)
      dial.easing_config(uid: "abc")
      expect(stub).to have_been_requested
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/vu_dials/dial_spec.rb`
Expected: FAIL — `uninitialized constant VuDials::Dial`.

- [ ] **Step 3: Write minimal implementation**

`lib/vu_dials/dial.rb`:

```ruby
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
```

Uncomment the dial require in `lib/vu_dials.rb`:

```ruby
require "vu_dials/dial"
# require "vu_dials/admin"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/vu_dials/dial_spec.rb`
Expected: PASS — 14 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add VuDials::Dial with the eleven dial-control methods"
```

---

## Task 5: VuDials::Admin

The five server-admin methods.

**Files:**
- Create: `lib/vu_dials/admin.rb`
- Test: `spec/vu_dials/admin_spec.rb`

**Interfaces:**
- Consumes: `VuDials::Client#request` from Tasks 2–3.
- Produces: `VuDials::Admin.new(host:, port:, admin_key:, timeout: 10)` with public methods `provision_dials`, `list_api_keys`, `remove_api_key(target_key:)`, `create_api_key(name:, dials:)`, `update_api_key(name:, target_key:, dials:)`. Auth param `"admin_key"`. `dials:` is an Array of UID strings joined with `;`.

- [ ] **Step 1: Write the failing test**

`spec/vu_dials/admin_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe VuDials::Admin do
  let(:admin) { described_class.new(host: "localhost", port: 5340, admin_key: "test-admin-key") }
  let(:base) { "http://localhost:5340/api/v0" }

  def ok(body = "{}")
    { status: 200, body: body }
  end

  it "uses the admin_key query param, not key" do
    stub = stub_request(:get, "#{base}/admin/keys/list")
           .with(query: { "admin_key" => "test-admin-key" }).to_return(ok)
    admin.list_api_keys
    expect(stub).to have_been_requested
  end

  describe "#provision_dials" do
    it "GETs dial/provision" do
      stub = stub_request(:get, "#{base}/dial/provision")
             .with(query: hash_including("admin_key" => "test-admin-key")).to_return(ok)
      admin.provision_dials
      expect(stub).to have_been_requested
    end

    it "propagates HTTP errors" do
      stub_request(:get, "#{base}/dial/provision").to_return(status: 403, body: "denied")
      expect { admin.provision_dials }.to raise_error(VuDials::HTTPError)
    end
  end

  describe "#list_api_keys" do
    it "GETs admin/keys/list and returns parsed JSON" do
      stub_request(:get, "#{base}/admin/keys/list").to_return(ok('{"keys":[]}'))
      expect(admin.list_api_keys).to eq("keys" => [])
    end
  end

  describe "#remove_api_key" do
    it "GETs admin/keys/remove with the target key" do
      stub = stub_request(:get, "#{base}/admin/keys/remove")
             .with(query: hash_including("key" => "victim-key")).to_return(ok)
      admin.remove_api_key(target_key: "victim-key")
      expect(stub).to have_been_requested
    end
  end

  describe "#create_api_key" do
    it "POSTs admin/keys/create with name and semicolon-joined dials" do
      stub = stub_request(:post, "#{base}/admin/keys/create")
             .with(query: hash_including("name" => "reader", "dials" => "uid1;uid2")).to_return(ok)
      admin.create_api_key(name: "reader", dials: %w[uid1 uid2])
      expect(stub).to have_been_requested
    end

    it "URL-encodes the joined dials" do
      stub = stub_request(:post, "#{base}/admin/keys/create")
             .with(query: hash_including("dials" => "a&b;c")).to_return(ok)
      admin.create_api_key(name: "n", dials: ["a&b", "c"])
      expect(stub).to have_been_requested
    end
  end

  describe "#update_api_key" do
    it "POSTs admin/keys/update with key, name, and dials" do
      stub = stub_request(:post, "#{base}/admin/keys/update")
             .with(query: hash_including(
               "key" => "target", "name" => "renamed", "dials" => "uid1;uid2"
             )).to_return(ok)
      admin.update_api_key(name: "renamed", target_key: "target", dials: %w[uid1 uid2])
      expect(stub).to have_been_requested
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/vu_dials/admin_spec.rb`
Expected: FAIL — `uninitialized constant VuDials::Admin`.

- [ ] **Step 3: Write minimal implementation**

`lib/vu_dials/admin.rb`:

```ruby
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

    def update_api_key(name:, target_key:, dials:)
      request(:post, "admin/keys/update",
              query: { "key" => target_key, "name" => name, "dials" => dials.join(";") })
    end

    private

    def auth_param
      "admin_key"
    end
  end
end
```

Uncomment the admin require in `lib/vu_dials.rb`:

```ruby
require "vu_dials/admin"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/vu_dials/admin_spec.rb`
Expected: PASS — 8 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add VuDials::Admin with provisioning and API key methods"
```

---

## Task 6: README and gem-build verification

Documents usage and confirms the whole gem builds and the full suite is green.

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

`README.md`:

````markdown
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
````

- [ ] **Step 2: Run the full suite via rake**

Run: `bundle exec rake`
Expected: PASS — all specs green (42 examples, 0 failures).

- [ ] **Step 3: Verify the gem builds**

Run: `gem build vu_dials.gemspec`
Expected: `Successfully built RubyGem  Name: vu_dials  Version: 0.1.0` and a `vu_dials-0.1.0.gem` file (already git-ignored).

- [ ] **Step 4: Verify the gem loads from a clean require**

Run: `ruby -Ilib -e 'require "vu_dials"; p VuDials::VERSION; p VuDials::Dial.instance_methods(false).sort'`
Expected: prints `"0.1.0"` and the eleven dial method names.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: add README and finalize vu_dials 0.1.0"
```

---

## Self-Review Notes

**Spec coverage:** Every spec section maps to a task — architecture/base client (Tasks 2–3), full `Dial` API 11 methods (Task 4), full `Admin` API 5 methods (Task 5), return-value & error semantics (Task 3, exercised throughout), preserved constraints/encoding (Tasks 2–5), testing with RSpec+WebMock (all tasks), gem scaffolding/version/errors (Task 1), README (Task 6). No gaps.

**Type/name consistency:** `request(method, api_call, query:, file:)`, `build_uri(api_call, query)`, and `auth_param` are used identically across Tasks 2–5. Constructors: `Dial#initialize(api_key:)`, `Admin#initialize(admin_key:)`, both delegating to `Client#initialize(key:)`. Consistent.

**No placeholders:** every code and test step contains complete, runnable content.
