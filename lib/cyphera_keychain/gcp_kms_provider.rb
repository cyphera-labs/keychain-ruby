# frozen_string_literal: true

require "base64"
require "securerandom"
require_relative "provider"

module CypheraKeychain
  # GCP Cloud KMS key provider.
  #
  # Uses the +google-cloud-kms+ gem to wrap locally-generated AES-256 data
  # keys. The plaintext is returned as key material and the KMS-encrypted
  # ciphertext is stored in metadata for envelope encryption workflows.
  #
  # The +key_name+ must be the full CryptoKey resource name:
  #
  #   projects/{project}/locations/{location}/keyRings/{ring}/cryptoKeys/{key}
  class GcpKmsProvider
    include KeyProvider

    # @param key_name [String] Full GCP KMS CryptoKey resource name.
    def initialize(key_name:)
      begin
        require "google/cloud/kms"
      rescue LoadError
        raise LoadError,
          "The 'google-cloud-kms' gem is required for GcpKmsProvider. " \
          "Add it to your Gemfile: gem 'google-cloud-kms'"
      end

      @key_name = key_name
      @cache = {}
    end

    # Return the highest-version active record for the given ref.
    def resolve(ref)
      return @cache[ref] if @cache.key?(ref)

      plaintext = SecureRandom.random_bytes(32)

      response = client.encrypt(
        name: @key_name,
        plaintext: plaintext
      )

      record = KeyRecord.new(
        ref: ref,
        version: 1,
        status: Status::ACTIVE,
        algorithm: "adf1",
        material: plaintext,
        metadata: {
          "ciphertext" => Base64.strict_encode64(response.ciphertext),
          "key_name" => @key_name
        }
      )

      @cache[ref] = record
      record
    rescue Google::Cloud::Error => e
      raise KeyNotFoundError.new(ref),
        "GCP KMS Encrypt failed for ref=#{ref.inspect}: #{e.message}"
    end

    # Return a specific version of the key for the given ref.
    def resolve_version(ref, version)
      record = resolve(ref)
      raise KeyNotFoundError.new(ref, version) unless record.version == version

      record
    end

    private

    def client
      @client ||= Google::Cloud::Kms.key_management_service
    end
  end
end
