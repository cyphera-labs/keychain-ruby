# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "securerandom"
require "uri"
require_relative "provider"

module CypheraKeychain
  # Azure Key Vault key provider.
  #
  # Uses the Azure Key Vault REST API directly via Net::HTTP (no external
  # gems required). Generates a random AES-256 data key locally and wraps
  # it with an RSA key stored in Azure Key Vault using the WrapKey
  # operation (RSA-OAEP algorithm).
  #
  # Authentication uses an OAuth2 bearer token which can be supplied
  # directly or obtained from the Azure Instance Metadata Service (IMDS)
  # for managed identities.
  class AzureKvProvider
    include KeyProvider

    # @param vault_url    [String] Azure Key Vault URL (e.g. "https://myvault.vault.azure.net").
    # @param key_name     [String] Name of the RSA key in Key Vault.
    # @param key_version  [String, nil] Optional specific key version.
    # @param access_token [String, nil] Optional OAuth2 bearer token.
    def initialize(vault_url:, key_name:, key_version: nil, access_token: nil)
      @vault_url = vault_url.chomp("/")
      @key_name = key_name
      @key_version = key_version
      @access_token = access_token
      @cache = {}
    end

    # Return the highest-version active record for the given ref.
    def resolve(ref)
      return @cache[ref] if @cache.key?(ref)

      plaintext = SecureRandom.random_bytes(32)

      token = fetch_access_token
      wrapped_key = wrap_key(plaintext, token)

      record = KeyRecord.new(
        ref: ref,
        version: 1,
        status: Status::ACTIVE,
        algorithm: "adf1",
        material: plaintext,
        metadata: {
          "wrapped_key" => wrapped_key,
          "vault_url" => @vault_url,
          "key_name" => @key_name
        }
      )

      @cache[ref] = record
      record
    end

    # Return a specific version of the key for the given ref.
    def resolve_version(ref, version)
      record = resolve(ref)
      raise KeyNotFoundError.new(ref, version) unless record.version == version

      record
    end

    private

    # Wrap a plaintext key using the Azure Key Vault WrapKey REST API.
    def wrap_key(plaintext, token)
      key_path = @key_version ? "/keys/#{@key_name}/#{@key_version}" : "/keys/#{@key_name}"
      uri = URI.parse("#{@vault_url}#{key_path}/wrapkey?api-version=7.4")

      # Base64url-encode without padding per Azure REST API spec.
      value = Base64.urlsafe_encode64(plaintext, padding: false)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{token}"
      request.body = JSON.generate({ alg: "RSA-OAEP", value: value })

      response = http.request(request)
      body = JSON.parse(response.body)

      if body.key?("error")
        message = body.dig("error", "message") || "unknown error"
        raise KeyNotFoundError.new(@key_name),
          "Azure Key Vault WrapKey failed: #{message}"
      end

      body.fetch("value") do
        raise KeyNotFoundError.new(@key_name),
          'Azure Key Vault WrapKey response missing "value" field.'
      end
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, JSON::ParserError => e
      raise KeyNotFoundError.new(@key_name),
        "Azure Key Vault WrapKey request failed: #{e.message}"
    end

    # Return the bearer token for Azure Key Vault API calls.
    #
    # If a token was provided at construction time, return it directly.
    # Otherwise attempt to obtain one from the Azure Instance Metadata
    # Service (IMDS) for managed identities.
    def fetch_access_token
      return @access_token if @access_token

      uri = URI.parse(
        "http://169.254.169.254/metadata/identity/oauth2/token" \
        "?api-version=2019-08-01" \
        "&resource=https%3A%2F%2Fvault.azure.net"
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 5
      http.read_timeout = 5

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Metadata"] = "true"

      response = http.request(request)
      body = JSON.parse(response.body)

      @access_token = body.fetch("access_token") do
        raise KeyNotFoundError.new(@key_name),
          "Azure IMDS response did not contain an access_token."
      end

      @access_token
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, JSON::ParserError => e
      raise KeyNotFoundError.new(@key_name),
        "Failed to obtain Azure access token from IMDS: #{e.message}. " \
        "Provide an access token explicitly or ensure managed identity is configured."
    end
  end
end
