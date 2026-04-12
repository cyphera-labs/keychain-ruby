# frozen_string_literal: true

require "base64"
require_relative "provider"

module CypheraKeychain
  # AWS KMS key provider.
  #
  # Uses the +aws-sdk-kms+ gem to call KMS GenerateDataKey, producing AES-256
  # data keys for each ref. The plaintext data key is returned as key material
  # and the encrypted (ciphertext) copy is stored in metadata for envelope
  # encryption workflows.
  #
  # Supports an optional endpoint URL override for LocalStack or other
  # KMS-compatible services.
  class AwsKmsProvider
    include KeyProvider

    # @param key_id       [String] KMS key ARN or alias.
    # @param region       [String] AWS region (default: "us-east-1").
    # @param endpoint_url [String, nil] Optional endpoint override (e.g. LocalStack).
    def initialize(key_id:, region: "us-east-1", endpoint_url: nil)
      begin
        require "aws-sdk-kms"
      rescue LoadError
        raise LoadError,
          "The 'aws-sdk-kms' gem is required for AwsKmsProvider. " \
          "Add it to your Gemfile: gem 'aws-sdk-kms'"
      end

      @key_id = key_id
      @region = region
      @endpoint_url = endpoint_url
      @cache = {}
    end

    # Return the highest-version active record for the given ref.
    def resolve(ref)
      return @cache[ref] if @cache.key?(ref)

      result = client.generate_data_key(
        key_id: @key_id,
        key_spec: "AES_256"
      )

      record = KeyRecord.new(
        ref: ref,
        version: 1,
        status: Status::ACTIVE,
        algorithm: "adf1",
        material: result.plaintext,
        metadata: {
          "ciphertext_blob" => Base64.strict_encode64(result.ciphertext_blob),
          "key_id" => result.key_id
        }
      )

      @cache[ref] = record
      record
    rescue Aws::KMS::Errors::ServiceError => e
      raise KeyNotFoundError.new(ref),
        "AWS KMS GenerateDataKey failed for ref=#{ref.inspect}: #{e.message}"
    end

    # Return a specific version of the key for the given ref.
    def resolve_version(ref, version)
      record = resolve(ref)
      raise KeyNotFoundError.new(ref, version) unless record.version == version

      record
    end

    private

    def client
      @client ||= begin
        opts = { region: @region }
        opts[:endpoint] = @endpoint_url if @endpoint_url
        Aws::KMS::Client.new(**opts)
      end
    end
  end
end
