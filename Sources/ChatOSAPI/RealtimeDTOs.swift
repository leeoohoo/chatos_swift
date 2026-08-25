import ChatOSCore
import Foundation

struct RealtimeEventEnvelopeDTO: Decodable, Sendable {
    var type: String
    var event: String
    var eventID: String
    var eventSequence: Int64
    var conversationID: String?
    var payload: RealtimePayloadDTO?
    var timestamp: String

    enum CodingKeys: String, CodingKey {
        case type
        case event
        case eventID = "event_id"
        case eventSequence = "event_sequence"
        case conversationID = "conversation_id"
        case payload
        case timestamp = "ts"
    }
}

struct RealtimePayloadDTO: Decodable, Sendable {
    var kind: String
    var conversationID: String?
    var turnID: String?
    var streamType: String?
    var raw: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case kind
        case conversationID = "conversation_id"
        case turnID = "conversation_turn_id"
        case streamType = "stream_type"
        case raw
    }
}

extension RealtimeEventEnvelopeDTO {
    func signal(expectedSessionID: String) -> ConversationRealtimeSignal? {
        guard type == "event", payload?.kind == "chat_stream" else { return nil }
        let sessionID = conversationID ?? payload?.conversationID ?? ""
        guard sessionID == expectedSessionID else { return nil }
        let normalizedType = (
            payload?.raw?["type"]?.stringValue
                ?? payload?.streamType
                ?? event
        ).lowercased()

        return ConversationRealtimeSignal(
            eventID: eventID,
            eventSequence: eventSequence,
            sessionID: sessionID,
            turnID: payload?.turnID,
            kind: normalizedType.realtimeKind,
            eventName: event,
            timestamp: timestamp
        )
    }
}

private extension String {
    var realtimeKind: ConversationRealtimeKind {
        if contains("cancel") { return .cancelled }
        if contains("fail") || contains("error") { return .failed }
        if contains("complete") || contains("finish") || contains("final") { return .completed }
        if contains("persist") || contains("callback") { return .persisted }
        if contains("start") { return .started }
        if contains("delta") || contains("stream") || contains("update") { return .updated }
        return .unknown
    }
}
