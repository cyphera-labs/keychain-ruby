# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "cyphera-keychain"
  spec.version       = "0.0.1.alpha1"
  spec.authors       = ["Cyphera"]
  spec.email         = ["sdk@cyphera.dev"]

  spec.summary       = "Key provider abstraction for Cyphera encryption SDKs"
  spec.description   = "Pluggable key-management providers (memory, env, file, Vault, AWS KMS, GCP KMS, Azure KV) for Cyphera FPE/encryption libraries."
  spec.homepage      = "https://github.com/cyphera-labs/keychain-ruby"
  spec.license       = "Apache-2.0"

  spec.required_ruby_version = ">= 3.1"

  spec.files         = Dir["lib/**/*.rb", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.add_development_dependency "aws-sdk-kms", "~> 1.0"
  spec.add_development_dependency "google-cloud-kms", "~> 2.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
