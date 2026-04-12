# frozen_string_literal: true

require_relative "provider"

module CypheraKeychain
  # Stub AWS KMS key provider.
  #
  # A real implementation would use the +aws-sdk-kms+ gem. This stub raises a
  # clear error directing users to install the necessary dependency.
  class AwsKmsProvider
    include KeyProvider

    def initialize(key_id:, region: "us-east-1", endpoint_url: nil)
      @key_id = key_id
      @region = region
      @endpoint_url = endpoint_url
    end

    def resolve(_ref)
      raise NotImplementedError,
        "AwsKmsProvider is a stub. Install the 'aws-sdk-kms' gem and use a real implementation."
    end

    def resolve_version(_ref, _version)
      raise NotImplementedError,
        "AwsKmsProvider is a stub. Install the 'aws-sdk-kms' gem and use a real implementation."
    end
  end
end
