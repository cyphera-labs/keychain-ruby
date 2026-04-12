# frozen_string_literal: true

module CypheraKeychain
  # Key status constants.
  module Status
    ACTIVE     = "active"
    DEPRECATED = "deprecated"
    DISABLED   = "disabled"
  end

  # Immutable value object representing a single key record.
  KeyRecord = Struct.new(
    :ref,
    :version,
    :status,
    :algorithm,
    :material,
    :tweak,
    :metadata,
    :created_at,
    keyword_init: true
  ) do
    def initialize(ref:, version:, status:, algorithm: "adf1", material: "".b, tweak: nil, metadata: {}, created_at: nil)
      super
      freeze
    end
  end

  # Raised when a key ref (and optional version) cannot be found.
  class KeyNotFoundError < StandardError
    attr_reader :ref, :version

    def initialize(ref, version = nil)
      @ref = ref
      @version = version
      if version
        super("key not found: ref=#{ref.inspect} version=#{version}")
      else
        super("key not found: ref=#{ref.inspect}")
      end
    end
  end

  # Raised when the requested key version is disabled.
  class KeyDisabledError < StandardError
    attr_reader :ref, :version

    def initialize(ref, version)
      @ref = ref
      @version = version
      super("key is disabled: ref=#{ref.inspect} version=#{version}")
    end
  end

  # Raised when records exist for a ref but none are active.
  class NoActiveKeyError < StandardError
    attr_reader :ref

    def initialize(ref)
      @ref = ref
      super("no active key found: ref=#{ref.inspect}")
    end
  end

  # Abstract base for all key providers.
  #
  # Subclasses must implement +resolve(ref)+ and +resolve_version(ref, version)+.
  module KeyProvider
    # Return the highest-version active record for encryption.
    def resolve(ref)
      raise NotImplementedError, "#{self.class}#resolve not implemented"
    end

    # Return a specific version of a key record for decryption.
    def resolve_version(ref, version)
      raise NotImplementedError, "#{self.class}#resolve_version not implemented"
    end
  end
end
