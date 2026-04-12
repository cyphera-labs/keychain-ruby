# frozen_string_literal: true

require_relative "vault_provider"
require_relative "aws_kms_provider"
require_relative "gcp_kms_provider"
require_relative "azure_kv_provider"

module CypheraKeychain
  # Bridge resolver for Cyphera SDK config-driven key sources.
  #
  # Called by the SDK when cyphera.json has "source" set to a cloud provider.
  # Returns raw key bytes.
  #
  # @param source [String] Provider name ("vault", "aws-kms", "gcp-kms", "azure-kv").
  # @param config [Hash]   Provider-specific configuration.
  # @return [String] Raw key material bytes.
  def self.resolve(source, config = {})
    ref = config["ref"] || config["path"] || config["arn"] || config["key"] || "default"

    provider = case source
    when "vault"
      VaultProvider.new(
        url: config["addr"] || ENV.fetch("VAULT_ADDR", "http://127.0.0.1:8200"),
        token: config["token"] || ENV["VAULT_TOKEN"],
        mount: config.fetch("mount", "secret")
      )
    when "aws-kms"
      AwsKmsProvider.new(
        key_id: config.fetch("arn", ""),
        region: config["region"] || ENV.fetch("AWS_REGION", "us-east-1"),
        endpoint_url: config["endpoint"]
      )
    when "gcp-kms"
      GcpKmsProvider.new(
        key_name: config.fetch("resource", "")
      )
    when "azure-kv"
      AzureKvProvider.new(
        vault_url: "https://#{config.fetch("vault", "")}.vault.azure.net",
        key_name: config.fetch("key", "")
      )
    else
      raise ArgumentError, "Unknown source: #{source}"
    end

    record = provider.resolve(ref)
    record.material
  end
end
