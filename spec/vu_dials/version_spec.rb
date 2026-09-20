# frozen_string_literal: true

RSpec.describe "VuDials::VERSION" do
  it "is a SemVer string" do
    expect(VuDials::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end

RSpec.describe "vu_dials.gemspec" do
  let(:gemspec) { Gem::Specification.load(File.expand_path("../../vu_dials.gemspec", __dir__)) }

  it "points homepage to the ruby gem repository" do
    expect(gemspec.homepage).to eq("https://github.com/erinlkolp/vu-dials-gem")
    expect(gemspec.metadata["homepage_uri"]).to eq("https://github.com/erinlkolp/vu-dials-gem")
    expect(gemspec.metadata["source_code_uri"]).to eq("https://github.com/erinlkolp/vu-dials-gem")
  end
end
