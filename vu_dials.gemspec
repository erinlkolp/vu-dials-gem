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
