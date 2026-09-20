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

    it "omits query params whose value is nil" do
      uri = key_client.send(:build_uri, "dial/abc/easing/dial", { "period" => 5, "step" => nil })
      expect(uri.to_s).to eq("http://localhost:5340/api/v0/dial/abc/easing/dial?key=mykey&period=5")
    end

    it "raises NotImplementedError when the base class is used directly" do
      base = described_class.new(host: "localhost", port: 5340, key: "k")
      expect { base.send(:build_uri, "dial/list") }.to raise_error(NotImplementedError)
    end
  end

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

    it "wraps a write timeout in ConnectionError" do
      stub_request(:get, %r{/api/v0/dial/list}).to_raise(Net::WriteTimeout)
      expect { client.send(:request, :get, "dial/list") }.to raise_error(VuDials::ConnectionError)
    end

    it "wraps a protocol error in ConnectionError" do
      stub_request(:get, %r{/api/v0/dial/list}).to_raise(Net::ProtocolError)
      expect { client.send(:request, :get, "dial/list") }.to raise_error(VuDials::ConnectionError)
    end

    it "configures write_timeout alongside open and read timeouts" do
      http_double = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http_double)
      expect(http_double).to receive(:open_timeout=).with(10)
      expect(http_double).to receive(:read_timeout=).with(10)
      expect(http_double).to receive(:write_timeout=).with(10)
      allow(http_double).to receive(:request).and_return(instance_double(Net::HTTPResponse, code: "200", body: "{}"))

      client.send(:request, :get, "dial/list")
    end

    it "does not mask a missing upload file as a ConnectionError" do
      expect {
        client.send(:request, :post, "dial/abc/image/set", file: "/no/such/file.png")
      }.to raise_error(Errno::ENOENT)
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
end
