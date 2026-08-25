import ChatOSCore
import Foundation

public actor ChatOSRealtimeClient: ConversationRealtimeStreaming {
    private let apiClient: ChatOSAPIClient
    private let conversationService: any ConversationRemoteServicing
    private let session: URLSession

    public init(
        apiClient: ChatOSAPIClient,
        conversationService: any ConversationRemoteServicing,
        session: URLSession = .shared
    ) {
        self.apiClient = apiClient
        self.conversationService = conversationService
        self.session = session
    }

    public func events(
        sessionID: String
    ) async -> AsyncThrowingStream<ConversationRealtimeSignal, Error> {
        AsyncThrowingStream { continuation in
            let consumer = Task {
                await consume(sessionID: sessionID, continuation: continuation)
            }
            continuation.onTermination = { _ in consumer.cancel() }
        }
    }

    private func consume(
        sessionID: String,
        continuation: AsyncThrowingStream<ConversationRealtimeSignal, Error>.Continuation
    ) async {
        var reconnectAttempt = 0

        while !Task.isCancelled {
            do {
                try await consumeConnection(sessionID: sessionID, continuation: continuation)
                reconnectAttempt = 0
            } catch is CancellationError {
                break
            } catch {
                reconnectAttempt += 1
                let delay = min(30, 1 << min(reconnectAttempt - 1, 5))
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    break
                }
            }
        }

        continuation.finish()
    }

    private func consumeConnection(
        sessionID: String,
        continuation: AsyncThrowingStream<ConversationRealtimeSignal, Error>.Continuation
    ) async throws {
        let ticket = try await conversationService.issueWebSocketTicket()
        guard let url = await apiClient.webSocketURL(path: "/realtime/ws", ticket: ticket) else {
            throw ChatOSAPIError.invalidEndpoint
        }

        let socket = session.webSocketTask(with: url)
        socket.resume()
        defer { socket.cancel(with: .goingAway, reason: nil) }

        try await socket.send(.string(Self.subscriptionMessage(sessionID: sessionID)))

        while !Task.isCancelled {
            let message = try await socket.receive()
            guard let data = message.data else { continue }
            if let signal = try Self.decodeSignal(data, sessionID: sessionID) {
                continuation.yield(signal)
            }
        }
    }

    private static func subscriptionMessage(sessionID: String) -> String {
        let payload: [String: Any] = [
            "type": "subscribe",
            "topics": [["scope": "conversation", "id": sessionID]],
        ]
        let data = try? JSONSerialization.data(withJSONObject: payload)
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    private static func decodeSignal(
        _ data: Data,
        sessionID: String
    ) throws -> ConversationRealtimeSignal? {
        guard let envelope = try? JSONDecoder().decode(RealtimeEventEnvelopeDTO.self, from: data) else {
            return nil
        }
        return envelope.signal(expectedSessionID: sessionID)
    }
}

private extension URLSessionWebSocketTask.Message {
    var data: Data? {
        switch self {
        case let .data(data): data
        case let .string(text): Data(text.utf8)
        @unknown default: nil
        }
    }
}
