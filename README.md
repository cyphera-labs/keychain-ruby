# cyphera-keychain (Ruby)

Key provider abstraction for Cyphera encryption SDKs.

## Installation

```ruby
gem "cyphera-keychain"
```

## Usage

```ruby
require "cyphera_keychain"

# In-memory provider
provider = CypheraKeychain::MemoryProvider.new(
  CypheraKeychain::KeyRecord.new(
    ref: "customer-primary",
    version: 1,
    status: CypheraKeychain::Status::ACTIVE,
    material: SecureRandom.random_bytes(32)
  )
)

record = provider.resolve("customer-primary")

# Environment variable provider
provider = CypheraKeychain::EnvProvider.new(prefix: "CYPHERA")
record = provider.resolve("customer-primary")
# reads CYPHERA_CUSTOMER_PRIMARY_KEY (hex or base64)

# File provider
provider = CypheraKeychain::FileProvider.new("keys.json")
record = provider.resolve("customer-primary")

# Vault provider (Net::HTTP, no external deps)
provider = CypheraKeychain::VaultProvider.new(
  url: "http://127.0.0.1:8200",
  token: "s.mytoken",
  mount: "secret"
)
record = provider.resolve("customer-primary")

# Bridge resolver (config-driven)
material = CypheraKeychain.resolve("vault", {
  "addr" => "http://127.0.0.1:8200",
  "token" => "s.mytoken",
  "ref" => "customer-primary"
})
```

## Providers

| Provider | Status | Backend |
|---|---|---|
| `MemoryProvider` | Complete | In-memory hash |
| `EnvProvider` | Complete | Environment variables |
| `FileProvider` | Complete | Local JSON file |
| `VaultProvider` | Complete | HashiCorp Vault KV v2 (Net::HTTP) |
| `AwsKmsProvider` | Stub | AWS KMS |
| `GcpKmsProvider` | Stub | GCP Cloud KMS |
| `AzureKvProvider` | Stub | Azure Key Vault |

## Development

```bash
bundle install
bundle exec ruby -Itest test/test_memory_provider.rb
```

## License

Apache-2.0
