import ChatOSCore
import Foundation

@MainActor
final class MessageTaskWorkspaceViewModel: ObservableObject {
    enum InspectorSection: String, CaseIterable {
        case detail = "任务详情"
        case process = "执行过程"
        case run = "运行详情"
    }

    let turn: ConversationTurn
    @Published private(set) var graph: MessageTaskGraphSnapshot?
    @Published private(set) var selectedTask: MessageTask?
    @Published var taskDetail: MessageTask?
    @Published var runDetail: MessageTaskRunDetail?
    @Published private(set) var isLoading = false
    @Published var isLoadingInspector = false
    @Published var isLoadingModelOutput = false
    @Published var isLoadingRun = false
    @Published var isLoadingMoreRunEvents = false
    @Published private(set) var isRetrying = false
    @Published var isMutatingPlan = false
    @Published var isPlanStopped = false
    @Published var displayMode: MessageTaskGraphDisplayMode = .reduced
    @Published var inspectorSection: InspectorSection = .detail
    @Published var retryInstruction = ""
    @Published var planActionMessage: String?
    @Published var errorMessage: String?

    let graphService: any MessageTaskGraphServicing
    let projectExecutionService: (any ProjectExecutionServicing)?
    var pollingTask: Task<Void, Never>?
    var loadedModelOutputRunID: String?

    init(
        turn: ConversationTurn,
        graphService: any MessageTaskGraphServicing,
        projectExecutionService: (any ProjectExecutionServicing)?
    ) {
        self.turn = turn
        self.graphService = graphService
        self.projectExecutionService = projectExecutionService
    }

    deinit {
        pollingTask?.cancel()
    }

    var displayGraph: MessageTaskGraphSnapshot? {
        graph.map { MessageTaskGraphNormalizer.normalize($0, mode: displayMode) }
    }

    var selectedTaskID: String? { selectedTask?.id }

    var executionState: ProjectExecutionConfirmationState {
        ProjectExecutionConfirmationState(
            context: turn.projectExecutionContext,
            graph: graph,
            conversationID: turn.sessionID
        )
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let graph = try await graphService.fetchGraph(
                    messageID: turn.userMessage.id,
                    lookup: baseLookup
                )
                applyGraph(graph)
            } catch {
                errorMessage = error.localizedDescription
            }
            startPollingIfNeeded()
            isLoading = false
        }
    }

    func refresh() {
        errorMessage = nil
        Task {
            do {
                applyGraph(
                    try await graphService.fetchGraph(
                        messageID: turn.userMessage.id,
                        lookup: baseLookup
                    )
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func select(_ task: MessageTask, section: InspectorSection? = nil) {
        selectedTask = task
        if let section { inspectorSection = section }
        loadInspector(for: task)
        ensureInspectorSectionLoaded()
    }

    func ensureInspectorSectionLoaded() {
        guard let task = taskDetail ?? selectedTask else { return }
        switch inspectorSection {
        case .detail:
            loadModelOutput(for: task)
        case .process:
            break
        case .run:
            guard runDetail == nil, !isLoadingRun else { return }
            loadRun(for: task)
        }
    }

    func retrySelectedRun() {
        guard let task = selectedTask,
              let runID = task.lastRunID ?? runDetail?.run.id,
              !isRetrying else { return }
        isRetrying = true
        errorMessage = nil
        let target = target(for: task)
        Task {
            do {
                _ = try await graphService.retryRun(
                    messageID: target.messageID,
                    runID: runID,
                    lookup: target.lookup,
                    instruction: retryInstruction
                )
                retryInstruction = ""
                inspectorSection = .run
                refresh()
                loadInspector(for: task)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRetrying = false
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    var baseLookup: MessageTaskLookup {
        turn.resolvedMessageTaskLookup
    }

    func applyGraph(_ graph: MessageTaskGraphSnapshot) {
        self.graph = graph
        let normalized = MessageTaskGraphNormalizer.normalize(graph, mode: displayMode)
        if let selectedTask,
           let refreshed = normalized.nodes.first(where: { $0.id == selectedTask.id })?.task {
            self.selectedTask = refreshed
        } else if self.selectedTask == nil {
            let initial = normalized.nodes.first(where: { $0.task.normalizedStatus == "blocked" })
                ?? normalized.nodes.first(where: \.isCurrentMessage)
                ?? normalized.nodes.first
            if let initial { select(initial.task) }
        }
    }

}
