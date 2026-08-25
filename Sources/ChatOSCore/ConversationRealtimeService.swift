public enum ConversationRealtimeKind: String, Sendable, Equatable {
    case started
    case updated
    case persisted
    case completed
    case failed
    case cancelled
    case unknown
}

public struct ConversationRealtimeSignal: Sendable, Equatable {
    public var eventID: String
    public var eventSequence: Int64
    public var sessionID: String
    public var turnID: String?
    public var kind: ConversationRealtimeKind
    public var eventName: String
    public var timestamp: String

    public init(
        eventID: String,
        eventSequence: Int64,
        sessionID: String,
        turnID: String?,
        kind: ConversationRealtimeKind,
        eventName: String,
        timestamp: String
    ) {
        self.eventID = eventID
        self.eventSequence = eventSequence
        self.sessionID = sessionID
        self.turnID = turnID
        self.kind = kind
        self.eventName = eventName
        self.timestamp = timestamp
    }
}

public protocol ConversationRealtimeStreaming: Sendable {
    func events(
        sessionID: String
    ) async -> AsyncThrowingStream<ConversationRealtimeSignal, Error>
}
