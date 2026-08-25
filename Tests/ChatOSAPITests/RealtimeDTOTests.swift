import Foundation
import XCTest
@testable import ChatOSAPI
@testable import ChatOSCore

final class RealtimeDTOTests: XCTestCase {
    func testChatStreamEnvelopeMapsStableIdentityAndSequence() throws {
        let envelope = try JSONDecoder().decode(
            RealtimeEventEnvelopeDTO.self,
            from: Data(fixtureJSON.utf8)
        )

        let signal = try XCTUnwrap(envelope.signal(expectedSessionID: "conversation-1"))
        XCTAssertEqual(signal.eventID, "event-1")
        XCTAssertEqual(signal.eventSequence, 101)
        XCTAssertEqual(signal.turnID, "turn-1")
        XCTAssertEqual(signal.kind, .completed)
    }

    func testWebSocketURLUsesGatewayBaseAndTicket() async throws {
        let client = ChatOSAPIClient(
            configuration: .init(baseURL: URL(string: "https://example.com/api/chatos")!)
        )

        let generatedURL = await client.webSocketURL(path: "/realtime/ws", ticket: "ticket-1")
        let url = try XCTUnwrap(generatedURL)
        XCTAssertEqual(url.scheme, "wss")
        XCTAssertEqual(url.path, "/api/chatos/realtime/ws")
        XCTAssertEqual(url.query, "ws_ticket=ticket-1")
    }

    private let fixtureJSON = #"""
    {
      "type": "event",
      "event": "chat.completed",
      "event_id": "event-1",
      "event_sequence": 101,
      "user_id": "user-1",
      "conversation_id": "conversation-1",
      "project_id": "project-1",
      "payload": {
        "kind": "chat_stream",
        "conversation_id": "conversation-1",
        "conversation_turn_id": "turn-1",
        "stream_type": "completed",
        "raw": { "type": "completed" }
      },
      "ts": "2026-08-24T03:00:00Z"
    }
    """#
}
