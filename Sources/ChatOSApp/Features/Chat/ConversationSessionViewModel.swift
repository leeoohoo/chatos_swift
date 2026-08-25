import ChatOSCore
import Foundation

@MainActor
final class ConversationSessionViewModel: ObservableObject {
    private static let historyPageSize = 10

    let sessionID: String
    @Published var allowsPlanMode: Bool

    @Published private(set) var turns: [ConversationTurn]
    @Published private(set) var hasOlder = false
    @Published private(set) var unreadNewerCount = 0
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingOlder = false
    @Published var isSending = false
    @Published private(set) var isUpdatingRuntimeSettings = false
    @Published private(set) var planModeEnabled = false
    @Published private(set) var reasoningEnabled = false
    @Published var historyError: String?
    @Published var selectedTurnID: String?
    @Published var draft = ""

    let historyStore: any ConversationHistoryStoring
    let commandService: (any ConversationCommandServicing)?
    let turnProcessService: (any TurnProcessServicing)?
    let messageTaskGraphService: (any MessageTaskGraphServicing)?
    let projectExecutionService: (any ProjectExecutionServicing)?
    private let remoteService: (any ConversationRemoteServicing)?
    private let realtimeService: (any ConversationRealtimeStreaming)?
    private let runtimeSettingsService: (any ConversationRuntimeSettingsServicing)?
    private var olderCursor: String?
    private var requestGeneration: Int64 = 0
    private var inFlightOlderCursor: String?
    private var realtimeTask: Task<Void, Never>?

    init(
        sessionID: String,
        allowsPlanMode: Bool = false,
        initialTurns: [ConversationTurn],
        historyStore: any ConversationHistoryStoring,
        remoteService: (any ConversationRemoteServicing)? = nil,
        realtimeService: (any ConversationRealtimeStreaming)? = nil,
        commandService: (any ConversationCommandServicing)? = nil,
        turnProcessService: (any TurnProcessServicing)? = nil,
        messageTaskGraphService: (any MessageTaskGraphServicing)? = nil,
        projectExecutionService: (any ProjectExecutionServicing)? = nil,
        runtimeSettingsService: (any ConversationRuntimeSettingsServicing)? = nil
    ) {
        self.sessionID = sessionID
        self.allowsPlanMode = allowsPlanMode
        self.turns = initialTurns
        self.selectedTurnID = initialTurns.last?.id
        self.historyStore = historyStore
        self.remoteService = remoteService
        self.realtimeService = realtimeService
        self.commandService = commandService
        self.turnProcessService = turnProcessService
        self.messageTaskGraphService = messageTaskGraphService
        self.projectExecutionService = projectExecutionService
        self.runtimeSettingsService = runtimeSettingsService

        Task { await bootstrap(initialTurns: initialTurns) }
    }

    deinit {
        realtimeTask?.cancel()
    }

    func refreshLatest() {
        guard let remoteService, !isRefreshing else { return }
        requestGeneration += 1
        let generation = requestGeneration
        isRefreshing = true
        historyError = nil

        Task {
            do {
                let page = try await remoteService.fetchHistory(
                    ConversationHistoryQuery(
                        sessionID: sessionID,
                        limit: Self.historyPageSize,
                        requestGeneration: generation
                    )
                )
                await historyStore.mergePage(page, sessionID: sessionID, origin: .latest)
                await refreshSnapshot()
            } catch {
                historyError = error.localizedDescription
            }
            isRefreshing = false
        }
    }

    func loadOlder() {
        guard let remoteService,
              let cursor = olderCursor,
              hasOlder,
              !isLoadingOlder,
              inFlightOlderCursor != cursor else { return }

        requestGeneration += 1
        let generation = requestGeneration
        inFlightOlderCursor = cursor
        isLoadingOlder = true
        historyError = nil

        Task {
            do {
                let page = try await remoteService.fetchHistory(
                    ConversationHistoryQuery(
                        sessionID: sessionID,
                        limit: Self.historyPageSize,
                        before: cursor,
                        requestGeneration: generation
                    )
                )
                await historyStore.mergePage(page, sessionID: sessionID, origin: .older)
                await refreshSnapshot()
            } catch {
                historyError = error.localizedDescription
            }
            if inFlightOlderCursor == cursor {
                inFlightOlderCursor = nil
            }
            isLoadingOlder = false
        }
    }

    func markNewerContentRead() {
        Task {
            await historyStore.markNewerContentRead(sessionID: sessionID)
            await refreshSnapshot()
        }
    }

    private func bootstrap(initialTurns: [ConversationTurn]) async {
        await loadRuntimeSettings()
        await historyStore.mergeCachedTurns(initialTurns, sessionID: sessionID)
        await refreshSnapshot()
        refreshLatest()
        startRealtime()
    }

    func setPlanModeEnabled(_ enabled: Bool) {
        guard allowsPlanMode, let runtimeSettingsService else { return }
        let previous = planModeEnabled
        planModeEnabled = enabled
        isUpdatingRuntimeSettings = true
        Task {
            do {
                let settings = try await runtimeSettingsService.updatePlanMode(
                    sessionID: sessionID,
                    enabled: enabled
                )
                applyRuntimeSettings(settings)
            } catch {
                planModeEnabled = previous
                historyError = error.localizedDescription
            }
            isUpdatingRuntimeSettings = false
        }
    }

    func setReasoningEnabled(_ enabled: Bool) {
        guard let runtimeSettingsService else { return }
        let previous = reasoningEnabled
        reasoningEnabled = enabled
        isUpdatingRuntimeSettings = true
        Task {
            do {
                let settings = try await runtimeSettingsService.updateReasoning(
                    sessionID: sessionID,
                    enabled: enabled
                )
                applyRuntimeSettings(settings)
            } catch {
                reasoningEnabled = previous
                historyError = error.localizedDescription
            }
            isUpdatingRuntimeSettings = false
        }
    }

    private func loadRuntimeSettings() async {
        guard let runtimeSettingsService else { return }
        do {
            applyRuntimeSettings(
                try await runtimeSettingsService.fetchSettings(sessionID: sessionID)
            )
        } catch {
            historyError = error.localizedDescription
        }
    }

    private func applyRuntimeSettings(_ settings: ConversationRuntimeSettings) {
        planModeEnabled = allowsPlanMode && settings.planModeEnabled
        reasoningEnabled = settings.reasoningEnabled
    }

    private func startRealtime() {
        guard let realtimeService, realtimeTask == nil else { return }
        let sessionID = sessionID

        realtimeTask = Task { [weak self] in
            let stream = await realtimeService.events(sessionID: sessionID)
            do {
                for try await signal in stream {
                    guard let self else { return }
                    switch signal.kind {
                    case .persisted, .completed, .failed, .cancelled:
                        self.refreshLatest()
                    case .started, .updated, .unknown:
                        break
                    }
                }
            } catch {
                guard let self else { return }
                self.historyError = error.localizedDescription
            }
        }
    }

    func refreshSnapshot() async {
        let snapshot = await historyStore.snapshot(sessionID: sessionID)
        turns = snapshot.turns
        olderCursor = snapshot.olderCursor
        hasOlder = snapshot.hasOlder
        unreadNewerCount = snapshot.unreadNewerCount
    }
}
