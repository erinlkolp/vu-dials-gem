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
      stub_request(:get, "#{base}/dial/list").with(query: hash_including("key" => "test-api-key"))
                                              .to_return(status: 500, body: "boom")
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
      stub = stub_request(:get, "#{base}/dial/a%26b/status")
             .with(query: hash_including("key" => "test-api-key")).to_return(ok)
      dial.info(uid: "a&b")
      expect(stub).to have_been_requested
    end

    it "percent-encodes spaces in uid as %20 rather than +" do
      stub = stub_request(:get, "#{base}/dial/a%20b/status")
             .with(query: hash_including("key" => "test-api-key")).to_return(ok)
      dial.info(uid: "a b")
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

    it "coerces float value to integer" do
      stub = stub_request(:get, "#{base}/dial/abc/set")
             .with(query: hash_including("value" => "75")).to_return(ok)
      dial.set_value(uid: "abc", value: 75.6)
      expect(stub).to have_been_requested
    end

    it "raises ArgumentError if value is nil" do
      expect { dial.set_value(uid: "abc", value: nil) }.to raise_error(ArgumentError, /value cannot be nil/)
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

    it "raises ArgumentError if any color channel is nil" do
      expect { dial.set_color(uid: "abc", red: nil, green: 50, blue: 50) }
        .to raise_error(ArgumentError, /cannot be nil/)
      expect { dial.set_color(uid: "abc", red: 50, green: nil, blue: 50) }
        .to raise_error(ArgumentError, /cannot be nil/)
      expect { dial.set_color(uid: "abc", red: 50, green: 50, blue: nil) }
        .to raise_error(ArgumentError, /cannot be nil/)
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
      stub = stub_request(:get, "#{base}/dial/abc/image/crc")
             .with(query: hash_including("key" => "test-api-key")).to_return(ok)
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
      stub = stub_request(:get, "#{base}/dial/abc/reload")
             .with(query: hash_including("key" => "test-api-key")).to_return(ok)
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

    it "GETs dial/{uid}/easing/dial with only period when step is omitted" do
      stub = stub_request(:get, "#{base}/dial/abc/easing/dial")
             .with(query: { "key" => "test-api-key", "period" => "5" }).to_return(ok)
      dial.set_easing(uid: "abc", period: 5)
      expect(stub).to have_been_requested
    end

    it "GETs dial/{uid}/easing/dial with only step when period is omitted" do
      stub = stub_request(:get, "#{base}/dial/abc/easing/dial")
             .with(query: { "key" => "test-api-key", "step" => "2" }).to_return(ok)
      dial.set_easing(uid: "abc", step: 2)
      expect(stub).to have_been_requested
    end

    it "raises ArgumentError if neither period nor step is provided" do
      expect { dial.set_easing(uid: "abc") }.to raise_error(ArgumentError, /period or step/)
    end
  end

  describe "#set_backlight_easing" do
    it "GETs dial/{uid}/easing/backlight with period/step" do
      stub = stub_request(:get, "#{base}/dial/abc/easing/backlight")
             .with(query: hash_including("period" => "5", "step" => "2")).to_return(ok)
      dial.set_backlight_easing(uid: "abc", period: 5, step: 2)
      expect(stub).to have_been_requested
    end

    it "GETs dial/{uid}/easing/backlight with only period when step is omitted" do
      stub = stub_request(:get, "#{base}/dial/abc/easing/backlight")
             .with(query: { "key" => "test-api-key", "period" => "5" }).to_return(ok)
      dial.set_backlight_easing(uid: "abc", period: 5)
      expect(stub).to have_been_requested
    end

    it "GETs dial/{uid}/easing/backlight with only step when period is omitted" do
      stub = stub_request(:get, "#{base}/dial/abc/easing/backlight")
             .with(query: { "key" => "test-api-key", "step" => "2" }).to_return(ok)
      dial.set_backlight_easing(uid: "abc", step: 2)
      expect(stub).to have_been_requested
    end

    it "raises ArgumentError if neither period nor step is provided" do
      expect { dial.set_backlight_easing(uid: "abc") }.to raise_error(ArgumentError, /period or step/)
    end
  end

  describe "#easing_config" do
    it "GETs dial/{uid}/easing/get" do
      stub = stub_request(:get, "#{base}/dial/abc/easing/get")
             .with(query: hash_including("key" => "test-api-key")).to_return(ok)
      dial.easing_config(uid: "abc")
      expect(stub).to have_been_requested
    end
  end
end
