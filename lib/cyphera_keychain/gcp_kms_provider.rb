# frozen_string_literal: true

require_relative "provider"

module CypheraKeychain
  # Stub GCP Cloud KMS key provider.
  #
  # A real implementation would use the +google-cloud-kms+ gem. This stub raises
  # a clear error directing users to install the necessary dependency.
  class GcpKmsProvider
    include KeyProvider

    def initialize(key_name:)
      @key_name = key_name
    end

    def resolve(_ref)
      raise NotImplementedError,
        "GcpKmsProvider is a stub. Install the 'google-cloud-kms' gem and use a real implementation."
    end

    def resolve_version(_ref, _version)
      raise NotImplementedError,
        "GcpKmsProvider is a stub. Install the 'google-cloud-kms' gem and use a real implementation."
    end
  end
end
