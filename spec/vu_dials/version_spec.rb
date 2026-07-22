# frozen_string_literal: true

RSpec.describe "VuDials::VERSION" do
  it "is a SemVer string" do
    expect(VuDials::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
