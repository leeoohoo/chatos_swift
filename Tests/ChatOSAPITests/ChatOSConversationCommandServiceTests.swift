import ChatOSCore
import Foundation
import XCTest
@testable import ChatOSAPI

final class ChatOSConversationCommandServiceTests: XCTestCase {
    func testNewTurnUsesRuntimeModelAndPostsChatCommand() async throws {
        let transport = CommandTransport()
        let client = ChatOSAPIClient(
            configuration: .init(baseURL: URL(string: "https://example.com/api/chatos")!),
            accessToken: "token",
            transport: transport
        )
        let service = ChatOSConversationCommandService(client: client)

        let ack = try await service.sendNewTurn(
            ConversationSendCommand(
                sessionID: "conversation-1",
                turnID: "turn-1",
                content: "hello"
            )
        )

        XCTAssertTrue(ack.accepted)
        XCTAssertEqual(ack.userMessageID, "message-1")
        let capturedCommandRequest = await transport.commandRequest()
        let commandRequest = try XCTUnwrap(capturedCommandRequest)
        let body = try XCTUnwrap(commandRequest.body)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(payload["conversation_id"] as? String, "conversation-1")
        XCTAssertEqual(payload["turn_id"] as? String, "turn-1")
        XCTAssertEqual(payload["model_config_id"] as? String, "model-config-1")
        XCTAssertEqual(payload["plan_mode"] as? Bool, false)
        let model = try XCTUnwrap(payload["ai_model_config"] as? [String: Any])
        XCTAssertEqual(model["model_name"] as? String, "gpt-5.6-terra")
    }

    func testCommandOverrideCarriesPlanModeToRustBackend() async throws {
        let transport = CommandTransport()
        let client = ChatOSAPIClient(
            configuration: .init(baseURL: URL(string: "https://example.com/api/chatos")!),
            accessToken: "token",
            transport: transport
        )
        _ = try await ChatOSConversationCommandService(client: client).sendNewTurn(
            ConversationSendCommand(
                sessionID: "conversation-1",
                turnID: "turn-plan",
                content: "先规划",
                reasoningEnabled: true,
                planModeEnabled: true
            )
        )

        let capturedRequest = await transport.commandRequest()
        let request = try XCTUnwrap(capturedRequest)
        let body = try XCTUnwrap(request.body)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["plan_mode"] as? Bool, true)
        XCTAssertEqual(payload["reasoning_enabled"] as? Bool, true)
    }

    func testGuidanceUsesDedicatedEndpoint() async throws {
        let transport = CommandTransport()
        let client = ChatOSAPIClient(
            configuration: .init(baseURL: URL(string: "https://example.com/api/chatos")!),
            accessToken: "token",
            transport: transport
        )

        _ = try await ChatOSConversationCommandService(client: client).sendGuidance(
            ConversationSendCommand(
                sessionID: "conversation-1",
                turnID: "turn-running",
                content: "continue"
            )
        )

        let capturedGuidanceRequest = await transport.guidanceRequest()
        let request = try XCTUnwrap(capturedGuidanceRequest)
        XCTAssertEqual(request.url.path, "/api/chatos/agent/chat/guidance")
    }
}

private actor CommandTransport: HTTPTransport {
    private var requests: [HTTPRequest] = []

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        let body: String
        switch request.url.path {
        case "/api/chatos/conversations/conversation-1/runtime-settings":
            body = #"{"selected_model_id":"model-config-1","selected_model_name":"gpt-5.6-terra","selected_thinking_level":"medium","remote_connection_id":null,"workspace_root":"/workspace","reasoning_enabled":true,"plan_mode_enabled":false}"#
        case "/api/chatos/ai-model-configs":
            body = #"[{"id":"model-config-1","name":"Terra","model_name":"gpt-5.6-terra","thinking_level":"medium","temperature":0.5,"enabled":true}]"#
        case "/api/chatos/agent/chat/send":
            body = #"{"accepted":true,"turn_id":"turn-1","user_message_id":"message-1"}"#
        case "/api/chatos/agent/chat/guidance":
            body = #"{"accepted":true,"turn_id":"turn-running"}"#
        default:
            return HTTPResponse(statusCode: 404, headers: [:], body: Data())
        }
        return HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
    }

    func commandRequest() -> HTTPRequest? {
        requests.first { $0.url.path.hasSuffix("/agent/chat/send") }
    }

    func guidanceRequest() -> HTTPRequest? {
        requests.first { $0.url.path.hasSuffix("/agent/chat/guidance") }
    }
}
