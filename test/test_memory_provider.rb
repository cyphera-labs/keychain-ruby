# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/cyphera_keychain"

KEY_MATERIAL = ["0123456789abcdef0123456789abcdef"].pack("H*").freeze

def make_record(ref: "k", version: 1, status: CypheraKeychain::Status::ACTIVE)
  CypheraKeychain::KeyRecord.new(
    ref: ref,
    version: version,
    status: status,
    material: KEY_MATERIAL
  )
end

class TestResolve < Minitest::Test
  def test_resolve_active_key
    provider = CypheraKeychain::MemoryProvider.new(make_record(ref: "k", version: 1, status: CypheraKeychain::Status::ACTIVE))
    record = provider.resolve("k")
    assert_equal "k", record.ref
    assert_equal 1, record.version
    assert_equal CypheraKeychain::Status::ACTIVE, record.status
  end

  def test_resolve_unknown_ref_raises
    provider = CypheraKeychain::MemoryProvider.new
    err = assert_raises(CypheraKeychain::KeyNotFoundError) { provider.resolve("missing") }
    assert_equal "missing", err.ref
    assert_nil err.version
  end

  def test_resolve_no_active_key_raises
    provider = CypheraKeychain::MemoryProvider.new(
      make_record(ref: "k", version: 1, status: CypheraKeychain::Status::DEPRECATED),
      make_record(ref: "k", version: 2, status: CypheraKeychain::Status::DISABLED)
    )
    err = assert_raises(CypheraKeychain::NoActiveKeyError) { provider.resolve("k") }
    assert_equal "k", err.ref
  end

  def test_resolve_returns_highest_active_version
    provider = CypheraKeychain::MemoryProvider.new(
      make_record(ref: "k", version: 1, status: CypheraKeychain::Status::ACTIVE),
      make_record(ref: "k", version: 2, status: CypheraKeychain::Status::ACTIVE),
      make_record(ref: "k", version: 3, status: CypheraKeychain::Status::DEPRECATED)
    )
    record = provider.resolve("k")
    assert_equal 2, record.version
  end

  def test_resolve_skips_deprecated_returns_next_active
    provider = CypheraKeychain::MemoryProvider.new(
      make_record(ref: "k", version: 1, status: CypheraKeychain::Status::ACTIVE),
      make_record(ref: "k", version: 2, status: CypheraKeychain::Status::DEPRECATED)
    )
    record = provider.resolve("k")
    assert_equal 1, record.version
  end
end

class TestResolveVersion < Minitest::Test
  def test_resolve_version_returns_correct_record
    provider = CypheraKeychain::MemoryProvider.new(
      make_record(ref: "k", version: 1, status: CypheraKeychain::Status::ACTIVE),
      make_record(ref: "k", version: 2, status: CypheraKeychain::Status::ACTIVE)
    )
    record = provider.resolve_version("k", 1)
    assert_equal 1, record.version
  end

  def test_resolve_version_disabled_raises
    provider = CypheraKeychain::MemoryProvider.new(make_record(ref: "k", version: 1, status: CypheraKeychain::Status::DISABLED))
    err = assert_raises(CypheraKeychain::KeyDisabledError) { provider.resolve_version("k", 1) }
    assert_equal "k", err.ref
    assert_equal 1, err.version
  end

  def test_resolve_version_missing_ref_raises
    provider = CypheraKeychain::MemoryProvider.new
    err = assert_raises(CypheraKeychain::KeyNotFoundError) { provider.resolve_version("missing", 1) }
    assert_equal "missing", err.ref
    assert_equal 1, err.version
  end

  def test_resolve_version_missing_version_raises
    provider = CypheraKeychain::MemoryProvider.new(make_record(ref: "k", version: 1, status: CypheraKeychain::Status::ACTIVE))
    err = assert_raises(CypheraKeychain::KeyNotFoundError) { provider.resolve_version("k", 99) }
    assert_equal 99, err.version
  end

  def test_resolve_version_deprecated_allowed
    provider = CypheraKeychain::MemoryProvider.new(make_record(ref: "k", version: 1, status: CypheraKeychain::Status::DEPRECATED))
    record = provider.resolve_version("k", 1)
    assert_equal 1, record.version
    assert_equal CypheraKeychain::Status::DEPRECATED, record.status
  end
end

class TestAdd < Minitest::Test
  def test_add_makes_key_resolvable
    provider = CypheraKeychain::MemoryProvider.new
    provider.add(make_record(ref: "k", version: 1, status: CypheraKeychain::Status::ACTIVE))
    record = provider.resolve("k")
    assert_equal 1, record.version
  end

  def test_add_updates_highest_active
    provider = CypheraKeychain::MemoryProvider.new(make_record(ref: "k", version: 1, status: CypheraKeychain::Status::ACTIVE))
    provider.add(make_record(ref: "k", version: 2, status: CypheraKeychain::Status::ACTIVE))
    record = provider.resolve("k")
    assert_equal 2, record.version
  end

  def test_add_multiple_refs
    provider = CypheraKeychain::MemoryProvider.new
    provider.add(make_record(ref: "alpha", version: 1, status: CypheraKeychain::Status::ACTIVE))
    provider.add(make_record(ref: "beta", version: 1, status: CypheraKeychain::Status::ACTIVE))
    assert_equal "alpha", provider.resolve("alpha").ref
    assert_equal "beta", provider.resolve("beta").ref
  end
end
