# frozen_string_literal: true

require_relative "provider"

module CypheraKeychain
  # In-memory key provider, thread-safe via Mutex.
  #
  # Accepts an arbitrary number of KeyRecord arguments at construction time,
  # plus additional records via +add+.
  class MemoryProvider
    include KeyProvider

    def initialize(*records)
      @lock = Mutex.new
      @store = {} # ref -> Array<KeyRecord> sorted descending by version
      records.each { |r| insert(r) }
    end

    # Add a KeyRecord to the in-memory store.
    def add(record)
      @lock.synchronize { insert(record) }
    end

    # Return the highest-version active record for the given ref.
    def resolve(ref)
      @lock.synchronize do
        versions = @store[ref]
        raise KeyNotFoundError.new(ref) unless versions

        versions.each do |record|
          return record if record.status == Status::ACTIVE
        end

        raise NoActiveKeyError.new(ref)
      end
    end

    # Return a specific version of the key for the given ref.
    def resolve_version(ref, version)
      @lock.synchronize do
        versions = @store[ref]
        raise KeyNotFoundError.new(ref, version) unless versions

        versions.each do |record|
          next unless record.version == version
          raise KeyDisabledError.new(ref, version) if record.status == Status::DISABLED

          return record
        end

        raise KeyNotFoundError.new(ref, version)
      end
    end

    private

    def insert(record)
      versions = (@store[record.ref] ||= [])
      versions << record
      versions.sort_by! { |r| -r.version }
    end
  end
end
