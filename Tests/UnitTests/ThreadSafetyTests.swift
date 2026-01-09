import Testing
import Foundation
@testable import SmartNet

@Suite("Thread Safety Tests")
struct ThreadSafetyTests {

  // MARK: - @ThreadSafe Property Wrapper Tests

  @Test("ThreadSafe wrapper allows concurrent reads")
  func concurrentReads() async throws {
    class Container {
      @ThreadSafe var value: Int = 42
    }

    let container = Container()
    let iterations = 1000

    await withTaskGroup(of: Int.self) { group in
      for _ in 0..<iterations {
        group.addTask {
          return container.value
        }
      }

      for await result in group {
        #expect(result == 42)
      }
    }
  }

  @Test("ThreadSafe wrapper handles concurrent writes with full replacement")
  func concurrentWrites() async throws {
    class Container {
      @ThreadSafe var value: Int = 0
    }

    let container = Container()
    let iterations = 100

    // Concurrent full writes (not read-modify-write)
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          container.value = i
        }
      }
    }

    // Value should be one of the written values (0..<iterations)
    #expect(container.value >= 0 && container.value < iterations)
  }

  @Test("ThreadSafe wrapper handles mixed reads and writes")
  func mixedReadsAndWrites() async throws {
    class Container {
      @ThreadSafe var value: String = "initial"
    }

    let container = Container()
    let values = ["one", "two", "three", "four", "five"]

    await withTaskGroup(of: Void.self) { group in
      // Writers
      for value in values {
        group.addTask {
          container.value = value
        }
      }

      // Readers - should always get a valid string, never crash
      for _ in 0..<50 {
        group.addTask {
          _ = container.value.count
        }
      }
    }

    // Final value should be one of the set values
    #expect(values.contains(container.value) || container.value == "initial")
  }

  @Test("ThreadSafe dynamic member lookup works")
  func dynamicMemberLookup() {
    struct Person {
      var name: String
      var age: Int
    }

    class Container {
      @ThreadSafe var person = Person(name: "John", age: 30)
    }

    let container = Container()

    #expect(container.person.name == "John")
    #expect(container.person.age == 30)

    container.person.name = "Jane"
    container.person.age = 25

    #expect(container.person.name == "Jane")
    #expect(container.person.age == 25)
  }

  // MARK: - ApiClient Thread Safety Tests

  @Test("Headers can be set and updated sequentially")
  func sequentialHeaderUpdates() {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    client.updateHeaders(["Header-1": "Value-1"])
    client.updateHeaders(["Header-2": "Value-2"])
    client.updateHeaders(["Header-3": "Value-3"])

    #expect(client.config.headers.count == 3)
    #expect(client.config.headers["Header-1"] == "Value-1")
    #expect(client.config.headers["Header-2"] == "Value-2")
    #expect(client.config.headers["Header-3"] == "Value-3")
  }

  @Test("ThreadSafe array handles concurrent full replacement")
  func concurrentArrayReplacement() async throws {
    class Container {
      @ThreadSafe var items: [Int] = []
    }

    let container = Container()
    let iterations = 50

    // Concurrent full array replacements (not append which is read-modify-write)
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          container.items = [i, i + 1, i + 2]
        }
      }
    }

    // Should have one of the written arrays (always 3 elements)
    #expect(container.items.count == 3)
  }

  @Test("Middlewares can be added from multiple threads")
  func concurrentMiddlewareAddition() async throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    let iterations = 50

    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          let middleware = ApiClient.Middleware(
            pathComponent: "path\(i)",
            preRequestCallback: { _ in },
            postResponseCallback: { _, _, _ in .next }
          )
          client.addMiddleware(middleware)
        }
      }
    }

    // Verify middlewares were added (we can't directly check count, but no crash = success)
    // The test passes if no thread safety issues occur
  }

  @Test("Middleware removal is thread-safe")
  func concurrentMiddlewareRemoval() async throws {
    let config = NetworkConfiguration(baseURL: URL(string: "https://api.test.com")!)
    let sessionConfig = URLSessionConfiguration.ephemeral
    let client = ApiClient(config: config, sessionConfiguration: sessionConfig, delegateQueue: nil)
    defer { client.destroy() }

    // Add middlewares first
    for i in 0..<20 {
      let middleware = ApiClient.Middleware(
        pathComponent: "path\(i)",
        preRequestCallback: { _ in },
        postResponseCallback: { _, _, _ in .next }
      )
      client.addMiddleware(middleware)
    }

    // Concurrently remove
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<20 {
        group.addTask {
          client.removeMiddleware(for: "path\(i)")
        }
      }
    }

    // No crash = success
  }

  // MARK: - PThreadMutex Tests

  @Test("PThreadMutex sync executes work atomically")
  func mutexSync() {
    let mutex = PThreadMutex()
    var counter = 0

    mutex.sync {
      counter += 1
    }

    #expect(counter == 1)
  }

  @Test("PThreadMutex trySync returns nil when locked")
  func mutexTrySync() {
    let mutex = PThreadMutex()
    var counter = 0

    mutex.unbalancedLock()

    let result = mutex.trySync {
      counter += 1
      return counter
    }

    mutex.unbalancedUnlock()

    #expect(result == nil)
    #expect(counter == 0)
  }

  @Test("Recursive mutex allows re-entry")
  func recursiveMutex() {
    let mutex = PThreadMutex(type: .recursive)
    var counter = 0

    mutex.sync {
      counter += 1
      mutex.sync {
        counter += 1
      }
    }

    #expect(counter == 2)
  }
}
