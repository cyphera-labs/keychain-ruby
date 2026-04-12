# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "uri"
require_relative "provider"

module CypheraKeychain
  # Key provider backed by HashiCorp Vault KV v2 secrets engine.
  #
  # Uses Net::HTTP directly -- no external gems required.
  #
  # Key records are stored at +{mount}/{ref}+ as secret data fields.
  #
  # Single-version secret data format:
  #
  #   {
  #     "version": "1",
  #     "status": "active",
  #     "algorithm": "adf1",
  #     "material": "<hex or base64>"
  #   }
  #
  # Multi-version: store a +versions+ JSON array as a field (advanced use).
  class VaultProvider
    include KeyProvider

    # @param url   [String] Vault server URL.
    # @param token [String, nil] Vault token.
    # @param mount [String] KV v2 mount path (default: "secret").
    def initialize(url: "http://127.0.0.1:8200", token: nil, mount: "secret")
      @base_uri = URI.parse(url)
      @token = token
      @mount = mount
    end

    # Return the highest-version active record for the given ref.
    def resolve(ref)
      data = read_data(ref)
      records = parse_records(ref, data)
      active = records.select { |r| r.status == Status::ACTIVE }
      raise NoActiveKeyError.new(ref) if active.empty?

      active.max_by(&:version)
    end

    # Return a specific version of the key for the given ref.
    def resolve_version(ref, version)
      data = read_data(ref)
      records = parse_records(ref, data)

      records.each do |record|
        next unless record.version == version
        raise KeyDisabledError.new(ref, version) if record.status == Status::DISABLED

        return record
      end

      raise KeyNotFoundError.new(ref, version)
    end

    private

    def read_data(ref)
      path = "/v1/#{@mount}/data/#{ref}"
      uri = @base_uri.dup
      uri.path = path

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Get.new(uri.request_uri)
      request["X-Vault-Token"] = @token if @token

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise KeyNotFoundError.new(ref)
      end

      body = JSON.parse(response.body)
      body.dig("data", "data") || raise(KeyNotFoundError.new(ref))
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, JSON::ParserError => e
      raise KeyNotFoundError.new(ref)
    end

    def decode_bytes(value)
      stripped = value.strip
      if stripped.length.even?
        begin
          return [stripped].pack("H*")
        rescue ArgumentError
          # fall through
        end
      end

      begin
        return Base64.strict_decode64(stripped)
      rescue ArgumentError
        # fall through
      end

      Base64.urlsafe_decode64(stripped + "==")
    end

    def parse_one(ref, data)
      raw = data["material"] || ""
      material = raw.empty? ? "".b : decode_bytes(raw)
      tweak_raw = data["tweak"]
      tweak = tweak_raw ? decode_bytes(tweak_raw) : nil

      KeyRecord.new(
        ref: data.fetch("ref", ref),
        version: (data["version"] || 1).to_i,
        status: data.fetch("status", "active"),
        algorithm: data.fetch("algorithm", "adf1"),
        material: material,
        tweak: tweak,
        metadata: data["metadata"] || {}
      )
    end

    def parse_records(ref, data)
      if data.key?("versions")
        versions = data["versions"]
        versions = JSON.parse(versions) if versions.is_a?(String)
        versions.map { |v| parse_one(ref, v) }
      else
        [parse_one(ref, data)]
      end
    end
  end
end
