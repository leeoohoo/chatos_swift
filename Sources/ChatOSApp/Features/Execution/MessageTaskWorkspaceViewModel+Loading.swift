import ChatOSCore
import Foundation

extension MessageTaskWorkspaceViewModel {
    func loadInspector(for task: MessageTask) {
        isLoadingInspector = true
        isLoadingRun = false
        taskDetail = nil
        runDetail = nil
        loadedModelOutputRunID = nil
        isLoadingModelOutput = false
        isLoadingMoreRunEvents = false
        let target = target(for: task)
        let requestedTaskID = task.id
        Task {
            defer {
                if selectedTask?.id == requestedTaskID {
                    isLoadingInspector = false
                }
            }
            do {
                let detail = try await graphService.fetchTask(
                    messageID: target.messageID,
                    taskID: task.id,
                    lookup: target.lookup
                )
                guard selectedTask?.id == requestedTaskID else { return }
                taskDetail = detail
                if inspectorSection == .detail {
                    loadModelOutput(for: detail)
                } else if inspectorSection == .run {
                    loadRun(for: detail)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadModelOutput(for task: MessageTask) {
        guard let runID = task.lastRunID,
              loadedModelOutputRunID != runID,
              !isLoadingModelOutput else { return }
        isLoadingModelOutput = true
        let target = target(for: task)
        let requestedTaskID = task.id
        Task {
            defer {
                if selectedTask?.id == requestedTaskID {
                    isLoadingModelOutput = false
                }
            }
            do {
                let detail = try await graphService.fetchRun(
                    messageID: target.messageID,
                    runID: runID,
                    lookup: target.lookup,
                    includeEvents: false,
                    eventLimit: 1,
                    eventOffset: 0
                )
                guard selectedTask?.id == requestedTaskID else { return }
                loadedModelOutputRunID = runID
                taskDetail = (taskDetail ?? task).merging(run: detail.run)
            } catch {
                guard selectedTask?.id == requestedTaskID else { return }
                errorMessage = "模型输出加载失败：\(error.localizedDescription)"
            }
        }
    }

    func loadRun(for task: MessageTask) {
        guard let runID = task.lastRunID, !isLoadingRun else { return }
        isLoadingRun = true
        let target = target(for: task)
        let requestedTaskID = task.id
        Task {
            defer {
                if selectedTask?.id == requestedTaskID {
                    isLoadingRun = false
                }
            }
            do {
                let detail = try await graphService.fetchRun(
                    messageID: target.messageID,
                    runID: runID,
                    lookup: target.lookup,
                    includeEvents: true,
                    eventLimit: 40,
                    eventOffset: 0
                )
                guard selectedTask?.id == requestedTaskID else { return }
                runDetail = detail
                loadedModelOutputRunID = runID
                taskDetail = detail.task.merging(run: detail.run)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadMoreRunEvents() {
        guard let task = taskDetail ?? selectedTask,
              let current = runDetail,
              current.eventsHasMore,
              !isLoadingMoreRunEvents else { return }
        let target = target(for: task)
        isLoadingMoreRunEvents = true
        Task {
            defer { isLoadingMoreRunEvents = false }
            do {
                let page = try await graphService.fetchRun(
                    messageID: target.messageID,
                    runID: current.run.id,
                    lookup: target.lookup,
                    includeEvents: true,
                    eventLimit: 50,
                    eventOffset: current.events.count
                )
                guard runDetail?.run.id == current.run.id else { return }
                var merged = current
                let existingIDs = Set(current.events.map(\.id))
                merged.events.append(contentsOf: page.events.filter { !existingIDs.contains($0.id) })
                merged.eventsTotal = page.eventsTotal
                merged.eventsHasMore = page.eventsHasMore
                merged.task = page.task
                merged.run = page.run
                runDetail = merged
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func target(for task: MessageTask) -> (messageID: String, lookup: MessageTaskLookup) {
        let messageID = task.sourceUserMessageID?.isEmpty == false
            ? task.sourceUserMessageID!
            : turn.userMessage.id
        return (
            messageID,
            MessageTaskLookup(
                sessionID: task.sourceSessionID ?? graph?.sourceSessionID ?? turn.sessionID,
                turnID: task.sourceTurnID ?? graph?.sourceTurnID ?? turn.id,
                sourceUserMessageID: task.sourceUserMessageID
                    ?? graph?.sourceUserMessageID
                    ?? turn.userMessage.id
            )
        )
    }

    func startPollingIfNeeded() {
        stopPolling()
        let shouldPoll = graph?.nodes.contains(where: { $0.task.isActive }) == true
            || executionState.phase == .planning
        guard shouldPoll else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                do {
                    let graph = try await self.graphService.fetchGraph(
                        messageID: self.turn.userMessage.id,
                        lookup: self.baseLookup
                    )
                    self.errorMessage = nil
                    self.applyGraph(graph)
                    if !graph.nodes.contains(where: { $0.task.isActive }),
                       self.executionState.phase != .planning { return }
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

extension MessageTask {
    var normalizedStatus: String {
        status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
    }

    var isActive: Bool {
        ["pending", "queued", "ready", "running", "processing", "in_progress", "doing"]
            .contains(normalizedStatus)
    }
}
