# frozen_string_literal: true

require "base64"
require "json"
require "time"
require_relative "provider"

module CypheraKeychain
  # Key provider that loads keys from a local JSON file.
  #
  # The file must have the structure:
  #
  #   {
  #     "keys": [
  #       {
  #         "ref": "customer-primary",
  #         "version": 1,
  #         "status": "active",
  #         "algorithm": "adf1",
  #         "material": "<hex or base64>",
  #         "tweak": "<hex or base64>",
  #         "metadata": {},
  #         "created_at": "2024-01-01T00:00:00"
  #       }
  #     ]
  #   }
  #
  # The file is read once at construction time.
  class FileProvider
    include KeyProvider

    def initialize(path)
      data = JSON.parse(File.read(path))
      @store = {} # ref -> Array<KeyRecord> sorted descending by version

      (data["keys"] || []).each do |obj|
        record = parse_record(obj)
        versions = (@store[record.ref] ||= [])
        versions << record
      end

      @store.each_value { |v| v.sort_by! { |r| -r.version } }
    end

    # Return the highest-version active record for the given ref.
    def resolve(ref)
      versions = @store[ref]
      raise KeyNotFoundError.new(ref) unless versions

      versions.each do |record|
        return record if record.status == Status::ACTIVE
      end

      raise NoActiveKeyError.new(ref)
    end

    # Return a specific version of the key for the given ref.
    def resolve_version(ref, version)
      versions = @store[ref]
      raise KeyNotFoundError.new(ref, version) unless versions

      versions.each do |record|
        next unless record.version == version
        raise KeyDisabledError.new(ref, version) if record.status == Status::DISABLED

        return record
      end

      raise KeyNotFoundError.new(ref, version)
    end

    private

    def decode_bytes(value)
      if value.match?(/\A[0-9a-fA-F]*\z/) && value.length.even?
        return [value].pack("H*")
      end

      begin
        return Base64.strict_decode64(value)
      rescue ArgumentError
        # fall through
      end

      Base64.urlsafe_decode64(value)
    end

    def parse_record(obj)
      material = obj["material"] ? decode_bytes(obj["material"]) : "".b
      tweak = obj["tweak"] ? decode_bytes(obj["tweak"]) : nil
      created_at = obj["created_at"] ? Time.iso8601(obj["created_at"]) : nil

      KeyRecord.new(
        ref: obj["ref"],
        version: obj["version"].to_i,
        status: obj["status"],
        algorithm: obj.fetch("algorithm", "adf1"),
        material: material,
        tweak: tweak,
        metadata: obj.fetch("metadata", {}),
        created_at: created_at
      )
    end
  end
end
