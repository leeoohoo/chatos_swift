public struct ConversationSendCommand: Sendable, Equatable {
    public var sessionID: String
    public var turnID: String
    public var content: String
    public var reasoningEnabled: Bool?
    public var planModeEnabled: Bool?

    public init(
        sessionID: String,
        turnID: String,
        content: String,
        reasoningEnabled: Bool? = nil,
        planModeEnabled: Bool? = nil
    ) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.content = content
        self.reasoningEnabled = reasoningEnabled
        self.planModeEnabled = planModeEnabled
    }
}

public struct ConversationCommandAck: Sendable, Equatable {
    public var accepted: Bool
    public var turnID: String
    public var userMessageID: String?

    public init(accepted: Bool, turnID: String, userMessageID: String?) {
        self.accepted = accepted
        self.turnID = turnID
        self.userMessageID = userMessageID
    }
}

public protocol ConversationCommandServicing: Sendable {
    func sendNewTurn(_ command: ConversationSendCommand) async throws -> ConversationCommandAck
    func sendGuidance(_ command: ConversationSendCommand) async throws -> ConversationCommandAck
}
