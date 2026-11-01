import Foundation
import Testing
@testable import SmartNet

@Suite("SSE Parser")
struct SSEParserTests {
  private func parse(_ text: String, with parser: inout SSEParser) -> [SSEEvent] {
    text.utf8.compactMap { parser.consume($0) }
  }

  private func parse(_ text: String) -> [SSEEvent] {
    var parser = SSEParser()
    return parse(text, with: &parser)
  }

  private func event(_ data: String, event: String = "message", id: String? = nil, retry: TimeInterval? = nil) -> SSEEvent {
    SSEEvent(id: id, event: event, data: data, retry: retry)
  }

  @Test("Dispatches only on a blank line")
  func dispatchesOnBlankLine() {
    #expect(parse("data: hello\n").isEmpty)
    #expect(parse("data: hello\n\n") == [event("hello")])
  }

  @Test("Joins multi-line data with LF and strips the final LF")
  func joinsMultilineData() {
    #expect(parse("data: a\ndata: b\ndata\n\n") == [event("a\nb\n")])
  }

  @Test("Event type applies to one event, then resets to message")
  func eventTypeResets() {
    #expect(parse("event: update\ndata: x\n\ndata: y\n\n") == [event("x", event: "update"), event("y")])
  }

  @Test("Last event ID persists across events and resets on empty id")
  func lastEventIDPersists() {
    var parser = SSEParser()
    #expect(parse("id: 1\ndata: a\n\ndata: b\n\n", with: &parser) == [event("a", id: "1"), event("b", id: "1")])
    #expect(parser.lastEventID == "1")
    #expect(parse("id\ndata: c\n\n", with: &parser) == [event("c")])
    #expect(parser.lastEventID == "")
  }

  @Test("Ignores id containing NULL")
  func ignoresIDWithNull() {
    #expect(parse("id: a\u{0}b\ndata: x\n\n") == [event("x")])
  }

  @Test("Parses retry in milliseconds and ignores non-digit values")
  func parsesRetry() {
    var parser = SSEParser()
    #expect(parse("retry: 2500\ndata: x\n\n", with: &parser) == [event("x", retry: 2.5)])
    #expect(parser.reconnectionTime == 2.5)
    #expect(parse("retry: 1a\nretry: -1\nretry:\ndata: y\n\n", with: &parser) == [event("y")])
    #expect(parser.reconnectionTime == 2.5)
  }

  @Test("Retry without data updates reconnection time without dispatching")
  func retryOnlyBlock() {
    var parser = SSEParser()
    #expect(parse("retry: 100\n\n", with: &parser).isEmpty)
    #expect(parser.reconnectionTime == 0.1)
  }

  @Test("Ignores comments, unknown fields and blocks without data")
  func ignoresNoise() {
    #expect(parse(": heartbeat\n\n:hb\nfoo: bar\nevent: x\n\ndata: x\n\n") == [event("x")])
  }

  @Test("Strips exactly one leading space from values")
  func stripsOneSpace() {
    #expect(parse("data:  two\n\ndata:none\n\ndata: a: b\n\n") == [event(" two"), event("none"), event("a: b")])
  }

  @Test("Accepts CRLF, CR and LF line endings")
  func lineEndings() {
    #expect(parse("data: a\r\n\r\ndata: b\r\rdata: c\n\ndata: d\r\n\n") == [event("a"), event("b"), event("c"), event("d")])
  }

  @Test("Strips a leading BOM only at stream start")
  func stripsLeadingBOM() {
    #expect(parse("\u{FEFF}data: a\n\n\u{FEFF}data: b\n\n") == [event("a")])
  }

  @Test("Decodes multi-byte UTF-8")
  func decodesUTF8() {
    #expect(parse("data: héllo 🎉\n\n") == [event("héllo 🎉")])
  }
}
