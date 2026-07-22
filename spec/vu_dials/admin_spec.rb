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
      stub_request(:get, "#{base}/dial/provision")
        .with(query: hash_including("admin_key" => "test-admin-key"))
        .to_return(status: 403, body: "denied")
      expect { admin.provision_dials }.to raise_error(VuDials::HTTPError)
    end
  end

  describe "#list_api_keys" do
    it "GETs admin/keys/list and returns parsed JSON" do
      stub_request(:get, "#{base}/admin/keys/list")
        .with(query: hash_including("admin_key" => "test-admin-key"))
        .to_return(ok('{"keys":[]}'))
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
