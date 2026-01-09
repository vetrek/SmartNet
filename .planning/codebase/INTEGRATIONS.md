# External Integrations

**Analysis Date:** 2026-01-09

## APIs & External Services

**Payment Processing:**
- Not applicable - This is a networking library, not an application

**Email/SMS:**
- Not applicable

**External APIs:**
- None required - Library is API-agnostic
- Works with any HTTP-based REST API
- Example app demonstrates usage with `https://api.publicapis.org/entries`

## Data Storage

**Databases:**
- Not applicable - No database integration

**File Storage:**
- Local file system only
- Downloads stored to user-specified destinations
- Uses `FileManager` for file operations

**Caching:**
- No built-in caching layer
- Uses standard `URLSession` caching via `URLCache`

## Authentication & Identity

**Auth Provider:**
- None built-in - Library is auth-agnostic

**Supported Auth Patterns:**
- Bearer token via headers - `Source/Core/ApiClient.swift`
  - Example: `headers["Authorization"] = "Bearer token"`
- Basic authentication via URLAuthenticationChallenge
- Custom header-based auth via middleware system - `Source/Core/ApiClient+Middleware.swift`
- Any auth pattern consumers implement via `Endpoint` headers

**SSL/TLS Configuration:**
- Server trust validation - `Source/Core/ApiClient.swift`
- Trusted domains list via `NetworkConfiguration.trustedDomains`

## Monitoring & Observability

**Error Tracking:**
- Not integrated - Consumer responsibility

**Analytics:**
- Not applicable

**Logs:**
- Built-in `SmartNetLogger` - `Source/Utils/Logger.swift`
  - Uses Apple's `os_log` framework
  - Levels: debug, info, warning, error, none
  - Subsystem: "com.smartnet"
  - Category: "networking"

## CI/CD & Deployment

**Hosting:**
- Not applicable - Library distributed via SPM

**CI Pipeline:**
- Not configured in this repository
- Standard `swift test` for testing

## Environment Configuration

**Development:**
- No environment variables required
- Configuration via `NetworkConfiguration` struct
- Example: baseURL, headers, timeouts, retry policy

**Staging:**
- Not applicable - Consumer configures per environment

**Production:**
- Consumers manage their own configuration
- No secrets stored in library

## Webhooks & Callbacks

**Incoming:**
- Not applicable

**Outgoing:**
- Not applicable

## Library Integration Points

**For Consumers:**

The library provides these integration points for external services:

1. **Custom Headers** - Add auth tokens, API keys via:
   - `NetworkConfiguration.headers` (global)
   - `Endpoint.headers` (per-request)

2. **Middleware System** - `Source/Core/ApiClient+Middleware.swift`
   - `preRequestCallback` - Modify requests, add auth
   - `postResponseCallback` - Handle responses, trigger retries
   - Path-based matching for targeted middleware

3. **Custom JSONDecoder** - `Source/Extensions/JSONDecoder.swift`
   - Inject custom decoder for response parsing

4. **Progress HUD Protocol** - `Source/Utils/Protocols/SNProgressHUD.swift`
   - Integrate custom loading indicators

5. **Retry Policies** - `Source/Core/RetryPolicy.swift`
   - Configure automatic retry behavior
   - Handle 429 rate limits with `Retry-After` header

---

*Integration audit: 2026-01-09*
*Update when adding/removing external services*
