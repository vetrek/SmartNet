import Foundation

public struct SSEEvent: Equatable, Sendable {
  public let id: String?
  public let event: String
  public let data: String
  public let retry: TimeInterval?

  public init(id: String? = nil, event: String = "message", data: String, retry: TimeInterval? = nil) {
    self.id = id
    self.event = event
    self.data = data
    self.retry = retry
  }
}

struct SSEParser {
  private(set) var lastEventID = ""
  private(set) var reconnectionTime: TimeInterval?
  private var line = [UInt8]()
  private var data = ""
  private var eventType = ""
  private var retry: TimeInterval?
  private var afterCarriageReturn = false
  private var atStreamStart = true

  mutating func consume(_ byte: UInt8) -> SSEEvent? {
    defer { afterCarriageReturn = byte == 0x0D }
    switch byte {
    case 0x0A where afterCarriageReturn:
      return nil
    case 0x0A, 0x0D:
      return processLine()
    default:
      line.append(byte)
      return nil
    }
  }

  private mutating func processLine() -> SSEEvent? {
    defer { line.removeAll(keepingCapacity: true) }
    if atStreamStart {
      atStreamStart = false
      if line.starts(with: [0xEF, 0xBB, 0xBF]) { line.removeFirst(3) }
    }
    guard !line.isEmpty else { return dispatch() }

    let colon = line.firstIndex(of: 0x3A)
    let field = String(decoding: line[..<(colon ?? line.endIndex)], as: UTF8.self)
    var value = colon.map { line[($0 + 1)...] } ?? []
    if value.first == 0x20 { value = value.dropFirst() }
    let string = String(decoding: value, as: UTF8.self)

    switch field {
    case "event":
      eventType = string
    case "data":
      data += string + "\n"
    case "id" where !value.contains(0):
      lastEventID = string
    case "retry" where !value.isEmpty && value.allSatisfy({ (0x30...0x39).contains($0) }):
      if let milliseconds = Int(string) {
        retry = TimeInterval(milliseconds) / 1000
        reconnectionTime = retry
      }
    default:
      break
    }
    return nil
  }

  private mutating func dispatch() -> SSEEvent? {
    defer {
      data = ""
      eventType = ""
      retry = nil
    }
    guard !data.isEmpty else { return nil }
    return SSEEvent(
      id: lastEventID.isEmpty ? nil : lastEventID,
      event: eventType.isEmpty ? "message" : eventType,
      data: String(data.dropLast()),
      retry: retry
    )
  }
}
