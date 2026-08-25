import ChatOSCore
import Foundation

extension SessionMessageDTO {
    var isTaskRunnerCallback: Bool {
        let mode = (messageMode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let taskRunner = metadata.object(at: "task_runner_async")
        let messageKind = taskRunner?.string(at: "message_kind")?.lowercased() ?? ""
        return mode == "task_runner_callback"
            || messageKind == "task_terminal_update"
            || messageKind == "task_lifecycle_update"
    }

    var isCancelledTaskCallback: Bool {
        let taskRunner = metadata.object(at: "task_runner_async")
        let event = taskRunner?.string(at: "event")?.lowercased()
        let status = taskRunner?.string(at: "status")?.lowercased()
        return isTaskRunnerCallback
            && (event == "task.cancelled"
                || event == "task.canceled"
                || status == "cancelled"
                || status == "canceled")
    }

    var taskRunnerCallbackReference: TaskRunnerCallbackReference? {
        guard isTaskRunnerCallback,
              let taskRunner = metadata.object(at: "task_runner_async"),
              let taskID = taskRunner.string(at: "task_id")?.trimmedNonEmpty else {
            return nil
        }
        return TaskRunnerCallbackReference(
            taskID: taskID,
            runID: taskRunner.string(at: "run_id")?.trimmedNonEmpty,
            event: taskRunner.string(at: "event")?.trimmedNonEmpty,
            status: taskRunner.string(at: "status")?.trimmedNonEmpty,
            sourceSessionID: taskRunner.string(at: "source_session_id")?.trimmedNonEmpty,
            sourceTurnID: taskRunner.string(at: "source_turn_id")?.trimmedNonEmpty,
            sourceUserMessageID: taskRunner.string(at: "source_user_message_id")?.trimmedNonEmpty
        )
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func object(at key: String) -> [String: JSONValue]? {
        guard case let .object(value) = self[key] else { return nil }
        return value
    }

    func string(at key: String) -> String? {
        self[key]?.stringValue
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
