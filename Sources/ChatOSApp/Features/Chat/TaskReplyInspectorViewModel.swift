import ChatOSCore
import Foundation

enum TaskReplyInspectorSection: String, CaseIterable {
    case process = "执行过程"
    case detail = "任务详情"
}

struct TaskReplySelection: Identifiable {
    var id: String { reply.id }
    let turn: ConversationTurn
    let reply: ConversationAssistantReply
    let initialSection: TaskReplyInspectorSection
}

@MainActor
final class TaskReplyInspectorViewModel: ObservableObject {
    let selection: TaskReplySelection
    @Published var section: TaskReplyInspectorSection
    @Published private(set) var task: MessageTask?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingModelOutput = false
    @Published private(set) var isRetrying = false
    @Published var retryInstruction = ""
    @Published var errorMessage: String?
    @Published private(set) var modelOutputError: String?

    private let service: any MessageTaskGraphServicing

    init(selection: TaskReplySelection, service: any MessageTaskGraphServicing) {
        self.selection = selection
        self.section = selection.initialSection
        self.service = service
    }

    func load() {
        guard !isLoading, task == nil, let callback = selection.reply.taskCallback else { return }
        isLoading = true
        errorMessage = nil
        modelOutputError = nil
        Task {
            do {
                let loadedTask = try await service.fetchTask(
                    messageID: callback.sourceUserMessageID ?? selection.turn.userMessage.id,
                    taskID: callback.taskID,
                    lookup: lookup(callback)
                )
                task = loadedTask
                isLoading = false
                await loadModelOutput(for: loadedTask, callback: callback)
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func retry() {
        guard let callback = selection.reply.taskCallback,
              let runID = callback.runID ?? task?.lastRunID,
              !isRetrying else { return }
        isRetrying = true
        errorMessage = nil
        Task {
            do {
                _ = try await service.retryRun(
                    messageID: callback.sourceUserMessageID ?? selection.turn.userMessage.id,
                    runID: runID,
                    lookup: lookup(callback),
                    instruction: retryInstruction
                )
                retryInstruction = ""
                task = nil
                modelOutputError = nil
                isRetrying = false
                load()
            } catch {
                errorMessage = error.localizedDescription
                isRetrying = false
            }
        }
    }

    private func loadModelOutput(
        for loadedTask: MessageTask,
        callback: TaskRunnerCallbackReference
    ) async {
        guard let runID = callback.runID ?? loadedTask.lastRunID else { return }
        isLoadingModelOutput = true
        defer { isLoadingModelOutput = false }
        do {
            let detail = try await service.fetchRun(
                messageID: callback.sourceUserMessageID ?? selection.turn.userMessage.id,
                runID: runID,
                lookup: lookup(callback),
                includeEvents: false,
                eventLimit: 1,
                eventOffset: 0
            )
            guard task?.id == loadedTask.id else { return }
            task = loadedTask.merging(run: detail.run)
        } catch {
            modelOutputError = error.localizedDescription
        }
    }

    private func lookup(_ callback: TaskRunnerCallbackReference) -> MessageTaskLookup {
        MessageTaskLookup(
            sessionID: callback.sourceSessionID ?? selection.turn.sessionID,
            turnID: callback.sourceTurnID ?? selection.turn.id,
            sourceUserMessageID: callback.sourceUserMessageID ?? selection.turn.userMessage.id
        )
    }
}
