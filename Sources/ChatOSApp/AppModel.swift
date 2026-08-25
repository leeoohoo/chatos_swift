import ChatOSAPI
import ChatOSConnector
import ChatOSCore
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: SidebarSelection?
    @Published var projectTab: ProjectWorkspaceTab = .messages
    @Published var interfaceLanguage = "中文"
    @Published var contextLanguage = "中文"
    @Published var interfaceFontSize: Double = UserDefaults.standard.object(
        forKey: "ChatOS.interfaceFontSize"
    ) as? Double ?? 14 {
        didSet {
            let normalized = min(18, max(12, interfaceFontSize))
            if normalized != interfaceFontSize {
                interfaceFontSize = normalized
            } else {
                UserDefaults.standard.set(normalized, forKey: "ChatOS.interfaceFontSize")
            }
        }
    }
    @Published var visualSession: VisualSessionPresentation?
    @Published private(set) var projectConversation: ConversationSessionViewModel?
    @Published private(set) var contactConversation: ConversationSessionViewModel?
    @Published private(set) var contacts: [ResourceItem] = []
    @Published private(set) var projects: [ResourceItem] = []
    @Published private(set) var workspaceProjects: [WorkspaceProject] = []
    @Published private(set) var isWorkspaceLoading = false
    @Published private(set) var workspaceError: String?

    let historyStore: ConversationHistoryStore
    let authentication: AuthenticationViewModel
    let localConnectorControl: LocalConnectorControlCenterViewModel

    let terminals = [
        ResourceItem(
            id: "terminal-local",
            title: "本机终端",
            subtitle: "可用",
            conversationID: nil,
            contactName: nil
        ),
    ]

    private let conversationService: ChatOSConversationService
    private let realtimeService: ChatOSRealtimeClient
    private let commandService: ChatOSConversationCommandService
    private let turnProcessService: ChatOSTurnProcessService
    let messageTaskGraphService: ChatOSMessageTaskGraphService
    let projectExecutionService: ChatOSProjectExecutionService
    private let runtimeSettingsService: ChatOSConversationRuntimeSettingsService
    private let workspaceService: ChatOSWorkspaceService
    let projectFilesystemService: NativeProjectFilesystemService
    let projectCodeNavigationService: NativeProjectCodeNavigationService
    let projectPlanService: ChatOSProjectPlanService
    let projectRunService: NativeProjectRunService
    private var conversationCache: [String: ConversationSessionViewModel] = [:]
    private var workspaceLoadGeneration: Int64 = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        let credentialStore = KeychainCredentialStore()
        let apiClient = ChatOSAPIClient(
            configuration: .init(baseURL: RuntimeConfiguration.apiBaseURL),
            credentialStore: credentialStore
        )
        let authenticationService = ChatOSAuthenticationService(
            client: apiClient,
            credentialStore: credentialStore
        )
        let conversationService = ChatOSConversationService(client: apiClient)
        let historyStore = ConversationHistoryStore()
        let connectorTicketProvider = ChatOSLocalConnectorPairingTicketProvider(client: apiClient)
        let localConnectorService = NativeLocalConnectorService(
            configuration: .init(
                gatewayBaseURL: RuntimeConfiguration.localConnectorCloudBaseURL,
                stateURL: RuntimeConfiguration.nativeConnectorStateURL
            ),
            ticketProvider: connectorTicketProvider
        )

        self.historyStore = historyStore
        self.authentication = AuthenticationViewModel(service: authenticationService)
        self.localConnectorControl = LocalConnectorControlCenterViewModel(
            service: localConnectorService
        )
        self.conversationService = conversationService
        self.workspaceService = ChatOSWorkspaceService(client: apiClient)
        self.projectFilesystemService = NativeProjectFilesystemService(connector: localConnectorService)
        self.projectCodeNavigationService = NativeProjectCodeNavigationService(connector: localConnectorService)
        self.projectPlanService = ChatOSProjectPlanService(client: apiClient)
        self.projectRunService = NativeProjectRunService(
            connector: localConnectorService,
            preferencesURL: RuntimeConfiguration.nativeConnectorStateURL
                .deletingLastPathComponent()
                .appendingPathComponent("ProjectRunSettings.json")
        )
        self.commandService = ChatOSConversationCommandService(client: apiClient)
        self.turnProcessService = ChatOSTurnProcessService(client: apiClient)
        self.messageTaskGraphService = ChatOSMessageTaskGraphService(client: apiClient)
        self.projectExecutionService = ChatOSProjectExecutionService(client: apiClient)
        self.runtimeSettingsService = ChatOSConversationRuntimeSettingsService(client: apiClient)
        self.realtimeService = ChatOSRealtimeClient(
            apiClient: apiClient,
            conversationService: conversationService
        )
        self.visualSession = nil

        authentication.$phase
            .removeDuplicates()
            .sink { [weak self] phase in
                self?.applyAuthenticationPhase(phase)
            }
            .store(in: &cancellables)
        localConnectorControl.$status
            .map { $0?.connectorRunning == true }
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                self?.refreshWorkspace()
            }
            .store(in: &cancellables)
        $selection
            .removeDuplicates()
            .sink { [weak self] selection in
                self?.activateConversation(for: selection)
            }
            .store(in: &cancellables)
        authentication.start()
    }

    var currentConversationID: String? {
        switch selection {
        case .contact:
            return contactConversation?.sessionID
        case .project:
            return projectConversation?.sessionID
        default:
            return nil
        }
    }

    var interfaceDynamicTypeSize: DynamicTypeSize {
        switch Int(interfaceFontSize.rounded()) {
        case ...12: .small
        case 13: .medium
        case 14: .large
        case 15: .xLarge
        case 16: .xxLarge
        case 17: .xxxLarge
        default: .accessibility1
        }
    }

    func toggleVisualSession() {
        guard var visualSession else { return }
        visualSession.isExpanded.toggle()
        self.visualSession = visualSession
    }

    func refreshWorkspace() {
        workspaceLoadGeneration += 1
        let generation = workspaceLoadGeneration
        isWorkspaceLoading = true
        workspaceError = nil

        Task {
            do {
                let snapshot = try await workspaceService.fetchWorkspace()
                guard generation == workspaceLoadGeneration else { return }
                await projectRunService.updateProjects(snapshot.projects)
                guard generation == workspaceLoadGeneration else { return }
                workspaceProjects = snapshot.projects
                let resources = WorkspaceResourceResolver.resolve(snapshot)
                contacts = resources.contacts
                projects = resources.projects
                reconcileSelection()
            } catch {
                guard generation == workspaceLoadGeneration else { return }
                workspaceError = error.localizedDescription
            }
            if generation == workspaceLoadGeneration {
                isWorkspaceLoading = false
            }
        }
    }

    private func applyAuthenticationPhase(_ phase: AuthenticationViewModel.Phase) {
        switch phase {
        case .authenticated:
            localConnectorControl.activate(pairIfNeeded: true)
            refreshWorkspace()
        case .signedOut:
            workspaceLoadGeneration += 1
            contacts = []
            projects = []
            workspaceProjects = []
            conversationCache = [:]
            projectConversation = nil
            contactConversation = nil
        case .restoring, .authenticating:
            break
        }
    }

    func workspaceProject(id: String) -> WorkspaceProject? {
        workspaceProjects.first(where: { $0.id == id })
    }

    private func reconcileSelection() {
        if case let .project(id) = selection, projects.contains(where: { $0.id == id }) { return }
        if case let .contact(id) = selection, contacts.contains(where: { $0.id == id }) { return }
        selection = projects.first.map { .project($0.id) }
            ?? contacts.first.map { .contact($0.id) }
    }

    private func activateConversation(for selection: SidebarSelection?) {
        switch selection {
        case let .project(id):
            let conversationID = projects.first(where: { $0.id == id })?.conversationID
            projectConversation = conversationID.map {
                conversation(for: $0, allowsPlanMode: true)
            }
            contactConversation = nil
        case let .contact(id):
            let conversationID = contacts.first(where: { $0.id == id })?.conversationID
            contactConversation = conversationID.map {
                conversation(for: $0, allowsPlanMode: false)
            }
            projectConversation = nil
        default:
            projectConversation = nil
            contactConversation = nil
        }
    }

    private func conversation(
        for sessionID: String,
        allowsPlanMode: Bool
    ) -> ConversationSessionViewModel {
        if let cached = conversationCache[sessionID] {
            cached.allowsPlanMode = allowsPlanMode
            return cached
        }
        let created = ConversationSessionViewModel(
            sessionID: sessionID,
            allowsPlanMode: allowsPlanMode,
            initialTurns: [],
            historyStore: historyStore,
            remoteService: conversationService,
            realtimeService: realtimeService,
            commandService: commandService,
            turnProcessService: turnProcessService,
            messageTaskGraphService: messageTaskGraphService,
            projectExecutionService: projectExecutionService,
            runtimeSettingsService: runtimeSettingsService
        )
        conversationCache[sessionID] = created
        return created
    }
}
