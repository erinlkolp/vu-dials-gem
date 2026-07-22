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
