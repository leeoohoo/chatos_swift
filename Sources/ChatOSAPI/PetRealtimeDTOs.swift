import ChatOSCore
import Foundation

struct PetRealtimeEnvelopeDTO: Decodable, Sendable {
    var type: String
    var event: String
    var eventID: String
    var eventSequence: Int64
    var conversationID: String?
    var projectID: String?
    var payload: PetRealtimePayloadDTO?
    var timestamp: String

    enum CodingKeys: String, CodingKey {
        case type, event, payload
        case eventID = "event_id"
        case eventSequence = "event_sequence"
        case conversationID = "conversation_id"
        case projectID = "project_id"
        case timestamp = "ts"
    }
}

struct PetRealtimePayloadDTO: Decodable, Sendable {
    var kind: String
    var conversationID: String?
    var turnID: String?
    var projectID: String?
    var streamType: String?
    var raw: [String: JSONValue]?
    var promptID: String?
    var action: String?
    var status: String?
    var title: String?
    var message: String?
    var reviewID: String?
    var taskID: String?
    var task: JSONValue?
    var activity: PetActivityInboxRecordDTO?

    enum CodingKeys: String, CodingKey {
        case kind, raw, action, status, title, message, task, activity
        case conversationID = "conversation_id"
        case turnID = "conversation_turn_id"
        case projectID = "project_id"
        case streamType = "stream_type"
        case promptID = "prompt_id"
        case reviewID = "review_id"
        case taskID = "task_id"
    }
}

extension PetRealtimeEnvelopeDTO {
    func petActivityEvent() -> PetActivityEvent? {
        guard type == "event", let payload else { return nil }
        switch payload.kind {
        case "ask_user_prompt":
            return askUserEvent(payload)
        case "task_board":
            return taskBoardEvent(payload)
        case "chat_stream":
            return chatStreamEvent(payload)
        case "pet_activity_inbox_updated":
            return inboxActivityEvent(payload)
        default:
            return nil
        }
    }

    private func inboxActivityEvent(_ payload: PetRealtimePayloadDTO) -> PetActivityEvent? {
        guard var activity = payload.activity?.model else { return .reconcile }
        activity.eventID = eventID
        activity.eventSequence = eventSequence
        switch activity.inboxStatus {
        case .unread, .displayed:
            return .upsert(activity)
        case .acknowledged, .ignored, .handled, .resolved, .expired:
            return .remove(id: activity.id)
        case nil:
            return .reconcile
        }
    }

    private func askUserEvent(_ payload: PetRealtimePayloadDTO) -> PetActivityEvent? {
        guard let promptID = payload.promptID else { return nil }
        let id = "ask-user:\(promptID)"
        let action = payload.action?.lowercased() ?? ""
        let status = payload.status?.lowercased() ?? ""
        if action.contains("resolved") || action.contains("cancel")
            || ["submitted", "completed", "cancelled", "canceled", "expired"].contains(status) {
            return .remove(id: id)
        }
        guard status == "pending" || action.contains("required") || action.contains("created") else {
            return nil
        }
        return .upsert(PetActivity(
            id: id,
            source: .askUserPrompt,
            kind: .waitingForUser,
            title: payload.title?.trimmedNonEmpty ?? "AI 正在等待你的输入",
            detail: payload.message?.trimmedNonEmpty,
            route: route(payload, promptID: promptID),
            eventID: eventID,
            eventSequence: eventSequence,
            updatedAt: eventDate
        ))
    }

    private func taskBoardEvent(_ payload: PetRealtimePayloadDTO) -> PetActivityEvent? {
        let action = payload.action?.lowercased() ?? ""
        if let reviewID = payload.reviewID {
            let id = "task-review:\(reviewID)"
            if action == "review_required" {
                return .upsert(PetActivity(
                    id: id,
                    source: .taskBoard,
                    kind: .waitingForUser,
                    title: "执行计划等待确认",
                    detail: "请检查任务节点和依赖关系",
                    route: route(payload),
                    eventID: eventID,
                    eventSequence: eventSequence,
                    updatedAt: eventDate
                ))
            }
            if action == "review_confirmed" || action == "review_cancelled" {
                return .remove(id: id)
            }
        }

        guard let taskID = payload.taskID ?? payload.task?.objectString("id") else { return nil }
        let status = payload.task?.objectString("status")?.lowercased() ?? payload.status?.lowercased() ?? ""
        let title = payload.task?.objectString("title") ?? "任务"
        let mapping = taskStatusMapping(status, title: title)
        guard let mapping else { return nil }
        var taskRoute = route(payload)
        taskRoute.taskID = taskID
        return .upsert(PetActivity(
            id: "task-board:\(taskID)",
            source: .taskBoard,
            kind: mapping.kind,
            title: mapping.title,
            route: taskRoute,
            eventID: eventID,
            eventSequence: eventSequence,
            updatedAt: eventDate,
            expiresAt: mapping.expiration.map { eventDate.addingTimeInterval($0) }
        ))
    }

    private func chatStreamEvent(_ payload: PetRealtimePayloadDTO) -> PetActivityEvent? {
        let raw = payload.raw ?? [:]
        let type = (raw["type"]?.stringValue ?? payload.streamType ?? event).lowercased()
        if type == "task_runner_callback" || event == "chat.task_runner.updated" {
            return taskRunnerEvent(payload, raw: raw)
        }

        let sessionID = resolvedConversationID(payload)
        guard !sessionID.isEmpty else { return nil }
        let activityID = "chat:\(sessionID):\(payload.turnID ?? "unknown")"
        let mapping: (PetActivityKind, String, String?, TimeInterval?)?
        if type == "start" || event.contains("turn.started") {
            mapping = (.working, "AI 已开始处理任务", "正在读取需求和项目上下文", nil)
        } else if type.contains("thinking") {
            mapping = (.working, "AI 正在分析需求", nil, nil)
        } else if type.contains("turn_phase") || type == "phase" {
            mapping = (.reviewing, "AI 进入新的处理阶段", safePhaseDetail(raw), nil)
        } else if type.contains("tools_start") || event.contains("tool.started") {
            let names = toolNames(raw)
            mapping = (
                .working,
                names.isEmpty ? "AI 正在调用工具" : "AI 正在调用：\(names.joined(separator: "、"))",
                nil,
                nil
            )
        } else if type.contains("tools_end") || event.contains("tool.completed") {
            mapping = (.working, "工具调用已完成", "AI 正在继续处理结果", nil)
        } else if type.contains("complete") || type.contains("finish") {
            mapping = (.succeeded, "AI 已完成本轮任务", nil, 6)
        } else if type.contains("fail") || type.contains("error") {
            mapping = (.failed, "AI 执行失败", safeErrorDetail(raw), 30)
        } else if type.contains("cancel") {
            mapping = (.cancelled, "AI 执行已取消", nil, 5)
        } else {
            mapping = nil
        }
        guard let mapping else { return nil }
        return .upsert(PetActivity(
            id: activityID,
            source: .chat,
            kind: mapping.0,
            title: mapping.1,
            detail: mapping.2,
            route: route(payload),
            eventID: eventID,
            eventSequence: eventSequence,
            updatedAt: eventDate,
            expiresAt: mapping.3.map { eventDate.addingTimeInterval($0) }
        ))
    }

    private func taskRunnerEvent(
        _ payload: PetRealtimePayloadDTO,
        raw: [String: JSONValue]
    ) -> PetActivityEvent? {
        guard let callbackEvent = raw["event"]?.stringValue?.lowercased() else { return nil }
        let taskID = raw.value(at: "result", "persisted_user_message", "metadata", "task_runner_async", "last_task_id")?.stringValue
            ?? payload.taskID
            ?? payload.turnID
            ?? eventID
        let runID = raw.value(at: "result", "persisted_user_message", "metadata", "task_runner_async", "last_run_id")?.stringValue
            ?? raw["run_id"]?.stringValue
        let messageID = raw.value(at: "result", "persisted_assistant_message", "id")?.stringValue
            ?? raw["message_id"]?.stringValue
        let detail = raw.value(at: "result", "persisted_assistant_message", "content")?.stringValue
            .map { String($0.prefix(180)) }
        let mapping: (PetActivityKind, String, TimeInterval?)?
        switch callbackEvent {
        case "task.created", "task.run.queued":
            mapping = (.working, "任务已进入执行队列", nil)
        case "task.run.started":
            mapping = (.working, "任务开始执行", nil)
        case "task.completed":
            mapping = (.succeeded, "任务已完成", nil)
        case "task.failed":
            mapping = (.failed, "任务执行失败", nil)
        case "task.blocked":
            mapping = (.blocked, "任务执行被阻塞", nil)
        case "task.cancelled":
            mapping = (.cancelled, "任务已取消", 5)
        default:
            mapping = nil
        }
        guard let mapping else { return nil }
        var taskRoute = route(payload, messageID: messageID)
        taskRoute.taskID = taskID
        taskRoute.runID = runID
        return .upsert(PetActivity(
            id: "task-runner:\(taskID)",
            source: .taskRunner,
            kind: mapping.0,
            title: mapping.1,
            detail: detail,
            route: taskRoute,
            eventID: eventID,
            eventSequence: eventSequence,
            updatedAt: eventDate,
            expiresAt: mapping.2.map { eventDate.addingTimeInterval($0) }
        ))
    }

    private func taskStatusMapping(
        _ status: String,
        title: String
    ) -> (kind: PetActivityKind, title: String, expiration: TimeInterval?)? {
        switch status {
        case "running", "processing", "in_progress", "doing":
            (.working, "任务「\(title)」正在执行", nil)
        case "completed", "done", "succeeded", "success":
            (.succeeded, "任务「\(title)」已完成", nil)
        case "failed", "error":
            (.failed, "任务「\(title)」执行失败", nil)
        case "blocked":
            (.blocked, "任务「\(title)」被阻塞", nil)
        case "cancelled", "canceled", "stopped":
            (.cancelled, "任务「\(title)」已取消", 5)
        default:
            nil
        }
    }

    private func route(
        _ payload: PetRealtimePayloadDTO,
        messageID: String? = nil,
        promptID: String? = nil
    ) -> PetActivityRoute {
        PetActivityRoute(
            projectID: projectID ?? payload.projectID,
            conversationID: resolvedConversationID(payload).trimmedNonEmpty,
            turnID: payload.turnID,
            messageID: messageID,
            promptID: promptID,
            taskID: payload.taskID
        )
    }

    private func resolvedConversationID(_ payload: PetRealtimePayloadDTO) -> String {
        conversationID ?? payload.conversationID ?? ""
    }

    private var eventDate: Date {
        ISO8601DateFormatter().date(from: timestamp) ?? Date()
    }

    private func safePhaseDetail(_ raw: [String: JSONValue]) -> String? {
        raw.value(at: "data", "phase")?.stringValue
            ?? raw.value(at: "data", "status")?.stringValue
            ?? raw.value(at: "data", "name")?.stringValue
    }

    private func safeErrorDetail(_ raw: [String: JSONValue]) -> String? {
        raw["error"]?.stringValue
            ?? raw["message"]?.stringValue
            ?? raw.value(at: "data", "error")?.stringValue
            ?? raw.value(at: "data", "message")?.stringValue
    }

    private func toolNames(_ raw: [String: JSONValue]) -> [String] {
        guard let calls = raw.value(at: "data", "tool_calls") else { return [] }
        let values: [JSONValue]
        switch calls {
        case let .array(items): values = items
        default: values = [calls]
        }
        var seen = Set<String>()
        return values.compactMap { value in
            guard case let .object(object) = value else { return nil }
            let name = object["name"]?.stringValue
                ?? object.value(at: "function", "name")?.stringValue
                ?? object["tool_name"]?.stringValue
            guard let name, seen.insert(name).inserted else { return nil }
            return name
        }
    }
}

private extension JSONValue {
    func objectString(_ key: String) -> String? {
        guard case let .object(object) = self else { return nil }
        return object[key]?.stringValue
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
