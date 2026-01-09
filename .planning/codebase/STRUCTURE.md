# Codebase Structure

**Analysis Date:** 2026-01-09

## Directory Layout

```
SmartNet/
├── Source/                 # Library source code
│   ├── Core/              # Client and orchestration
│   ├── Endpoint/          # Request definitions
│   │   └── Protocol/      # Core protocols
│   ├── Response/          # Response modeling
│   ├── Utils/             # Utilities and helpers
│   │   └── Protocols/     # Utility protocols
│   └── Extensions/        # Swift extensions
├── Tests/                  # Test code
│   ├── UnitTests/         # Fast, isolated tests
│   └── IntegrationTests/  # Full request cycle tests
├── Example/               # Demo application
│   └── SmartNetDemo/      # SwiftUI demo app
├── Package.swift          # SPM manifest
├── README.md              # Documentation
├── CLAUDE.md              # AI assistant instructions
└── .swiftlint.yml         # Linting configuration
```

## Directory Purposes

**Source/Core/**
- Purpose: Main client class and request execution
- Contains: ApiClient and all its extensions
- Key files:
  - `ApiClient.swift` - Main class (358 lines)
  - `ApiClient+Async.swift` - async/await methods (85 lines)
  - `ApiClient+Combine.swift` - Combine publishers (131 lines)
  - `ApiClient+Closure.swift` - Callback methods (469 lines)
  - `ApiClient+Download.swift` - Download operations (429 lines)
  - `ApiClient+Upload.swift` - Upload operations (467 lines)
  - `ApiClient+Middleware.swift` - Middleware system (69 lines)
  - `ApiClient+CURL.swift` - Debug logging
  - `NetworkConfiguration.swift` - Global config (84 lines)
  - `RetryPolicy.swift` - Retry strategies (284 lines)
  - `ApiClientProtocol.swift` - Public protocol (277 lines)
  - `DownloadClientProtocol.swift` - Download interface
  - `UploadClientProtocol.swift` - Upload interface

**Source/Endpoint/**
- Purpose: Request definition and builders
- Contains: Endpoint types and body encoding
- Key files:
  - `Endpoint.swift` - Generic endpoint with builder (286 lines)
  - `HTTPBody.swift` - Body encoding (159 lines)
  - `MultipartFormEndpoint.swift` - Multipart forms (346 lines)
  - `DownloadEndpoint.swift` - Download-specific endpoint
  - `QueryParameters.swift` - Query param wrapper (41 lines)
- Subdirectories:
  - `Protocol/` - Core protocols (`Requestable.swift` - 308 lines)

**Source/Response/**
- Purpose: Response modeling
- Contains: Response wrapper and result type
- Key files:
  - `Response.swift` - Response wrapper (62 lines)
  - `Result.swift` - Result enum (65 lines)

**Source/Utils/**
- Purpose: Cross-cutting utilities
- Contains: Error types, logging, thread safety
- Key files:
  - `NetworkError.swift` - Error enum (146 lines)
  - `Logger.swift` - SmartNetLogger (98 lines)
  - `ThreadSafe.swift` - Property wrapper (168 lines)
  - `AnyProgressiveTransferTask.swift` - Type-erased task
- Subdirectories:
  - `Protocols/` - `SNProgressHUD.swift`

**Source/Extensions/**
- Purpose: Swift standard library extensions
- Contains: Utility extensions
- Key files:
  - `Encodable+.swift` - Encodable to dictionary
  - `JSONDecoder.swift` - Custom defaults
  - `String+.swift` - String utilities

**Tests/UnitTests/**
- Purpose: Fast, isolated component tests
- Contains: 12 test files (~3,200 lines total)
- Key files:
  - `RetryPolicyTests.swift` (465 lines)
  - `MultipartFormDataTests.swift` (487 lines)
  - `HTTPPayloadTests.swift` (389 lines)
  - `EndpointBuilderTests.swift` (350 lines)
  - `MockApiClient.swift` (299 lines)

**Tests/IntegrationTests/**
- Purpose: Full request cycle with mocks
- Contains: 8 test files (~1,600 lines total)
- Key files:
  - `ErrorHandlingTests.swift` (423 lines)
  - `ClosureRequestTests.swift` (246 lines)
  - `FileOperationTests.swift` (243 lines)
  - `TestHelpers.swift` (164 lines)

## Key File Locations

**Entry Points:**
- `Source/Core/ApiClient.swift` - Main client class
- `Source/Core/ApiClientProtocol.swift` - Public protocol

**Configuration:**
- `Package.swift` - SPM manifest, targets, dependencies
- `.swiftlint.yml` - Linting rules
- `Source/Core/NetworkConfiguration.swift` - Runtime config

**Core Logic:**
- `Source/Core/ApiClient+Closure.swift` - Request execution
- `Source/Core/RetryPolicy.swift` - Retry strategies
- `Source/Endpoint/Protocol/Requestable.swift` - URL building

**Testing:**
- `Tests/UnitTests/` - Unit tests
- `Tests/IntegrationTests/` - Integration tests
- `Tests/IntegrationTests/TestHelpers.swift` - Shared utilities

**Documentation:**
- `README.md` - User documentation
- `CLAUDE.md` - AI assistant instructions

## Naming Conventions

**Files:**
- PascalCase for all Swift files: `ApiClient.swift`, `NetworkError.swift`
- Extension pattern: `ApiClient+Feature.swift` (Async, Combine, Closure, etc.)
- Protocol files: `ApiClientProtocol.swift`, `Requestable.swift`
- Test files: `FeatureTests.swift`

**Directories:**
- PascalCase for source: `Core/`, `Endpoint/`, `Utils/`
- PascalCase for tests: `UnitTests/`, `IntegrationTests/`
- Conceptual grouping by responsibility

**Special Patterns:**
- `+` for extensions: `ApiClient+Async.swift`
- No barrel/index files (SPM handles exports)
- Protocols in dedicated `Protocol/` subdirectory

## Where to Add New Code

**New Feature:**
- Primary code: `Source/Core/` (if client-related) or `Source/Endpoint/` (if request-related)
- Tests: `Tests/UnitTests/` for isolated tests, `Tests/IntegrationTests/` for full cycle
- Protocol: Add to `Source/Core/ApiClientProtocol.swift` if public API

**New Endpoint Type:**
- Implementation: `Source/Endpoint/NewEndpoint.swift`
- Protocol conformance: Conform to `Requestable`
- Tests: `Tests/UnitTests/NewEndpointTests.swift`

**New ApiClient Extension:**
- Implementation: `Source/Core/ApiClient+Feature.swift`
- Protocol: Update `ApiClientProtocol.swift` if adding public methods
- Tests: Both unit and integration tests

**New Error Type:**
- Add case to `Source/Utils/NetworkError.swift`
- Update retry conditions in `Source/Core/RetryPolicy.swift` if applicable
- Add tests in `Tests/UnitTests/`

**Utilities:**
- Shared helpers: `Source/Utils/`
- Extensions: `Source/Extensions/`

## Special Directories

**.build/**
- Purpose: SPM build artifacts
- Source: Generated by `swift build`
- Committed: No (gitignored)

**.swiftpm/**
- Purpose: SPM and Xcode metadata
- Source: Generated by SPM/Xcode
- Committed: Partially (package resolution)

**Example/**
- Purpose: Demo application
- Source: Manual SwiftUI app demonstrating library usage
- Committed: Yes

---

*Structure analysis: 2026-01-09*
*Update when directory structure changes*
