# frozen_string_literal: true

require "base64"
require_relative "provider"

module CypheraKeychain
  # Key provider that reads keys from environment variables.
  #
  # For a ref of "customer-primary" and prefix "CYPHERA", the provider looks
  # for +CYPHERA_CUSTOMER_PRIMARY_KEY+ (hex or base64 encoded) and optionally
  # +CYPHERA_CUSTOMER_PRIMARY_TWEAK+.
  #
  # All keys provided via environment variables are treated as version 1 and
  # status active.
  class EnvProvider
    include KeyProvider

    def initialize(prefix: "CYPHERA")
      @prefix = prefix.chomp("_")
    end

    # Return the (sole) active key for the given ref from env vars.
    def resolve(ref)
      load_key(ref)
    end

    # Return the key for the given ref and version.
    #
    # Only version 1 exists for env-var-backed keys; any other version raises
    # KeyNotFoundError.
    def resolve_version(ref, version)
      raise KeyNotFoundError.new(ref, version) unless version == 1

      load_key(ref)
    end

    private

    def env_key(ref, suffix)
      normalized = ref.upcase.tr("-.", "_")
      "#{@prefix}_#{normalized}_#{suffix}"
    end

    def decode_bytes(value)
      # Try hex first
      if value.match?(/\A[0-9a-fA-F]*\z/) && value.length.even?
        return [value].pack("H*")
      end

      # Try standard base64
      begin
        decoded = Base64.strict_decode64(value)
        return decoded
      rescue ArgumentError
        # fall through
      end

      # URL-safe base64
      Base64.urlsafe_decode64(value)
    end

    def load_key(ref)
      key_var = env_key(ref, "KEY")
      raw = ENV[key_var]
      raise KeyNotFoundError.new(ref) if raw.nil?

      material = decode_bytes(raw)

      tweak = nil
      tweak_var = env_key(ref, "TWEAK")
      raw_tweak = ENV[tweak_var]
      tweak = decode_bytes(raw_tweak) if raw_tweak

      KeyRecord.new(
        ref: ref,
        version: 1,
        status: Status::ACTIVE,
        material: material,
        tweak: tweak
      )
    end
  end
end
