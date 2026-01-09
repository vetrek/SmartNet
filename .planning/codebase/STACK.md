# Technology Stack

**Analysis Date:** 2026-01-09

## Languages

**Primary:**
- Swift 5.9 - All application code (`Package.swift`)

**Secondary:**
- Swift 5.3 - Example app (`Example/Package.swift`)

## Runtime

**Environment:**
- iOS 13.0+ (minimum deployment target) - `Package.swift`
- macOS 10.15+ (Catalina) - `Package.swift`
- No external runtime dependencies

**Package Manager:**
- Swift Package Manager (SPM)
- Lockfile: `.build/.lock` (build artifacts)

## Frameworks

**Core:**
- Foundation - All source files (networking, data, URL handling)
- URLSession - `Source/Core/ApiClient.swift` (HTTP client)
- Combine - `Source/Core/ApiClient+Combine.swift` (reactive paradigm)

**Platform Support:**
- Darwin (pthread) - `Source/Utils/ThreadSafe.swift` (thread safety)
- os.log - `Source/Utils/Logger.swift` (system logging)

**Testing:**
- Swift Testing framework - All test files use `import Testing`
- `@Suite` and `@Test` attributes for test organization

**Build/Dev:**
- SwiftLint - `.swiftlint.yml` (code linting)
- No external build tools required

## Key Dependencies

**Critical:**
- None - Zero external dependencies

**Infrastructure:**
- Foundation built-ins only (URLSession, JSONEncoder/Decoder, Data, etc.)
- All functionality implemented in-house

## Configuration

**Environment:**
- No environment variables required
- Configuration via `NetworkConfiguration` struct at runtime
- Optional trusted domains for SSL pinning

**Build:**
- `Package.swift` - Swift Package Manager manifest
- `.swiftlint.yml` - SwiftLint rules configuration
- `Source/Info.plist` - Bundle metadata

## Platform Requirements

**Development:**
- macOS with Xcode (any modern version supporting Swift 5.9)
- No additional tooling required

**Production:**
- Distributed as Swift Package
- Added via SPM: `https://github.com/user/SmartNet.git`
- Runs on iOS 13+ and macOS 10.15+

---

*Stack analysis: 2026-01-09*
*Update after major dependency changes*
