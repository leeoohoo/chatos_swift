import ChatOSCore
import Foundation

extension SessionMessageDTO {
    var resolvedTurnID: String {
        turnID?.nonEmpty
            ?? metadata.value(at: "historyProcess", "turnId")?.stringValue
            ?? metadata.value(at: "conversation_turn_id")?.stringValue
            ?? metadata.value(at: "task_runner_async", "source_turn_id")?.stringValue
            ?? id
    }

    var finalTurnID: String? {
        metadata.value(at: "historyFinalForTurnId")?.stringValue
            ?? metadata.value(at: "conversation_turn_id")?.stringValue
            ?? metadata.value(at: "task_runner_async", "source_turn_id")?.stringValue
            ?? turnID?.nonEmpty
    }

    var resolvedRevision: Int64 {
        if let protocolRevision, protocolRevision > 0 {
            return protocolRevision
        }
        let date = DateParser.parse(updatedAt ?? createdAt)
        return max(1, Int64((date?.timeIntervalSince1970 ?? 0) * 1_000))
    }

    func domainMessage(role: ChatMessage.Role, fallbackDate: Date) -> ChatMessage {
        ChatMessage(
            id: id,
            role: role,
            text: content,
            createdAt: DateParser.parse(createdAt) ?? fallbackDate
        )
    }
}

enum DateParser {
    static func parse(_ value: String?) -> Date? {
        guard let value = value?.nonEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
