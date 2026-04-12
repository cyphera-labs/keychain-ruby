# frozen_string_literal: true

require_relative "provider"

module CypheraKeychain
  # Stub Azure Key Vault key provider.
  #
  # A real implementation would use the +azure-security-keyvault-keys+ gem.
  # This stub raises a clear error directing users to install the necessary
  # dependency.
  class AzureKvProvider
    include KeyProvider

    def initialize(vault_url:, key_name:)
      @vault_url = vault_url
      @key_name = key_name
    end

    def resolve(_ref)
      raise NotImplementedError,
        "AzureKvProvider is a stub. Install the Azure Key Vault gems and use a real implementation."
    end

    def resolve_version(_ref, _version)
      raise NotImplementedError,
        "AzureKvProvider is a stub. Install the Azure Key Vault gems and use a real implementation."
    end
  end
end
