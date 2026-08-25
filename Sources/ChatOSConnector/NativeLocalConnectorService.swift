import ChatOSCore
import CryptoKit
import Foundation

public struct NativeConnectorConfiguration: Sendable {
    public var gatewayBaseURL: URL
    public var stateURL: URL

    public init(gatewayBaseURL: URL, stateURL: URL) {
        self.gatewayBaseURL = gatewayBaseURL
        self.stateURL = stateURL
    }
}

public actor NativeLocalConnectorService: LocalConnectorControlServicing {
    private static let accessTokenAccount = "gateway-access-token-v1"

    private let configuration: NativeConnectorConfiguration
    private let ticketProvider: any LocalConnectorPairingTicketProviding
    let gateway: NativeConnectorGateway
    let stateStore: NativeConnectorStateStore
    let pluginInstaller: NativePluginInstaller
    private let secretStore = NativeConnectorSecretStore()
    var state: NativeConnectorPersistentState
    private var cachedAccessToken: String?
    private var hasLoadedAccessToken = false
    private var cachedDeviceIdentity: NativeConnectorDeviceIdentity?
    private var gatewayConnected = false
    var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    var pendingApprovals: [LocalConnectorPendingApproval] = []
    var pendingApprovalContinuations: [String: CheckedContinuation<NativeApprovalDecision, Never>] = [:]
    var seenRelayNonces: [String: Int64] = [:]

    public init(
        configuration: NativeConnectorConfiguration,
        ticketProvider: any LocalConnectorPairingTicketProviding
    ) {
        self.configuration = configuration
        self.ticketProvider = ticketProvider
        self.gateway = NativeConnectorGateway(baseURL: configuration.gatewayBaseURL)
        self.stateStore = NativeConnectorStateStore(stateURL: configuration.stateURL)
        self.pluginInstaller = NativePluginInstaller(
            rootURL: configuration.stateURL
                .deletingLastPathComponent()
                .appendingPathComponent("Plugins", isDirectory: true)
        )
        self.state = (try? stateStore.load()) ?? .empty
    }

    public func fetchStatus() async throws -> LocalConnectorStatus {
        if state.deviceID != nil {
            try? await importLegacyWorkspacesIfNeeded()
        }
        if state.deviceID != nil, !gatewayConnected {
            try? await connectGateway()
        }
        return statusSnapshot()
    }

    public func pairWithCurrentChatOSSession(deviceName: String?) async throws -> LocalConnectorStatus {
        let resolvedName = deviceName?.trimmedNonEmpty ?? Host.current().localizedName ?? "Mac"
        let ticket = try await ticketProvider.issueLocalConnectorPairingTicket()
        let login = try await gateway.exchange(ticket: ticket, deviceName: resolvedName)
        try secretStore.save(Data(login.token.utf8), account: Self.accessTokenAccount)
        cachedAccessToken = login.token
        hasLoadedAccessToken = true
        let identity = try deviceIdentity()
        let device = try await gateway.createDevice(
            token: login.token,
            displayName: resolvedName,
            publicKey: identity.publicKey
        )
        let workspace = try await ensureDefaultWorkspace(
            token: login.token,
            deviceID: device.id,
            publicKey: identity.publicKey
        )
        state.user = login.user.domainModel
        state.deviceID = device.id
        state.deviceName = resolvedName
        state.workspaces = [workspace]
        try? await importLegacyWorkspacesIfNeeded()
        try stateStore.save(state)
        try await connectGateway()
        try? await Task.sleep(for: .milliseconds(200))
        return statusSnapshot()
    }

    public func disconnect() async throws -> LocalConnectorStatus {
        let token = try accessToken()
        if let deviceID = state.deviceID, let token {
            try? await gateway.disconnectDevice(token: token, id: deviceID)
        }
        stopGatewayConnection()
        try secretStore.delete(account: Self.accessTokenAccount)
        cachedAccessToken = nil
        hasLoadedAccessToken = true
        state.user = nil
        state.deviceID = nil
        state.deviceName = nil
        state.workspaces = []
        try stateStore.save(state)
        return statusSnapshot()
    }

    public func fetchRuntimeSettings() async throws -> LocalConnectorRuntimeSettings {
        runtimeSettingsSnapshot()
    }

    public func updateDeveloperMode(_ enabled: Bool) async throws -> LocalConnectorRuntimeSettings {
        state.developerMode = enabled
        try stateStore.save(state)
        return runtimeSettingsSnapshot()
    }

    public func fetchSystemPermissions() async throws -> LocalConnectorSystemPermissions {
        NativeSystemPermissions.snapshot()
    }

    public func requestSystemPermission(id: String) async throws -> LocalConnectorSystemPermissions {
        await MainActor.run { NativeSystemPermissions.request(id) }
        return NativeSystemPermissions.snapshot()
    }

    public func executeTerminal(
        workspaceID: String,
        commandLine: String,
        cwd: String?
    ) async throws -> LocalConnectorTerminalResult {
        guard let workspace = state.workspaces.first(where: { $0.id == workspaceID }) else {
            throw NativeConnectorError.workspaceUnavailable
        }
        let result = try NativeTerminalExecutor.execute(
            command: "/bin/zsh",
            args: ["-lc", commandLine],
            cwd: cwd ?? workspace.absoluteRoot,
            workspace: workspace
        )
        let now = ISO8601DateFormatter().string(from: Date())
        state.commandHistory.insert(
            .init(
                id: UUID().uuidString,
                source: "native-terminal",
                workspaceAlias: workspace.alias,
                cwd: result.cwd,
                display: commandLine,
                status: result.success ? "completed" : "failed",
                exitCode: result.exitCode,
                stdoutPreview: result.stdout.prefixText(2_000),
                stderrPreview: result.stderr.prefixText(2_000),
                error: result.error,
                startedAt: now
            ),
            at: 0
        )
        state.commandHistory = Array(state.commandHistory.prefix(1_000))
        try stateStore.save(state)
        return result
    }

    public func fetchCommandHistory(limit: Int) async throws -> [LocalConnectorCommandHistoryEntry] {
        Array(state.commandHistory.prefix(max(1, min(limit, 200))))
    }

    public func clearCommandHistory() async throws {
        state.commandHistory = []
        try stateStore.save(state)
    }

    public func fetchApprovalSettings() async throws -> LocalConnectorApprovalSettings {
        .init(defaultMode: state.approvalMode, history: state.approvalHistory)
    }

    public func updateDefaultApprovalMode(
        _ mode: LocalConnectorApprovalMode,
        riskAcknowledged: Bool
    ) async throws -> LocalConnectorApprovalSettings {
        if mode != .requestApproval, !riskAcknowledged {
            throw NativeConnectorError.server(
                status: 409,
                message: "提高审批权限前需要明确确认风险。"
            )
        }
        if mode == .autoApproval,
           state.commandApprovalModelConfigID?.trimmedNonEmpty == nil {
            throw NativeConnectorError.server(
                status: 409,
                message: "请先在 AI 模型配置中选择本机审批 Agent 模型。"
            )
        }
        state.approvalMode = mode
        try stateStore.save(state)
        return .init(defaultMode: mode, history: state.approvalHistory)
    }

    public func fetchPendingApprovals() async throws -> [LocalConnectorPendingApproval] {
        pendingApprovals
    }

    public func resolveApproval(id: String, decision: String) async throws {
        let pending = pendingApprovals.first(where: { $0.id == id })
        pendingApprovals.removeAll(where: { $0.id == id })
        let continuation = pendingApprovalContinuations.removeValue(forKey: id)
        if let pending {
            state.approvalHistory.insert(
                .init(
                    id: UUID().uuidString,
                    command: pending.command,
                    cwd: pending.cwd,
                    source: pending.source,
                    mode: state.approvalMode,
                    decision: decision,
                    risk: pending.risk,
                    reason: pending.reason,
                    createdAt: ISO8601DateFormatter().string(from: Date())
                ),
                at: 0
            )
            try stateStore.save(state)
        }
        switch decision {
        case "accept", "acceptForSession", "approve":
            continuation?.resume(returning: .approve(
                reason: "用户已在本机批准。",
                rememberAllow: decision == "acceptForSession"
            ))
        default:
            continuation?.resume(returning: .deny(reason: "用户已在本机拒绝。"))
        }
    }

    public func fetchSandboxBackends() async throws -> [LocalConnectorSandboxBackend] {
        [
            .init(
                backend: "native-macos",
                status: "ready",
                selectable: true,
                filesystemIsolation: true,
                networkIsolation: true,
                processTreeControl: true,
                message: "由 Swift Native Connector 在本机执行权限边界。"
            ),
        ]
    }

    public func fetchSandboxSettings() async throws -> LocalConnectorSandboxSettings {
        sandboxSettingsSnapshot()
    }

    public func updateSandboxSettings(
        enabled: Bool?,
        permissionProfileID: String?,
        approvalPolicy: String?,
        approvalReviewer: String?,
        networkAccess: String?
    ) async throws -> LocalConnectorSandboxSettings {
        if let enabled { state.sandboxEnabled = enabled }
        if let permissionProfileID { state.permissionProfileID = permissionProfileID }
        if let approvalPolicy { state.approvalPolicy = approvalPolicy }
        if let approvalReviewer { state.approvalReviewer = approvalReviewer }
        if let networkAccess { state.networkAccess = networkAccess }
        state.policyRevision = "native-\(ISO8601DateFormatter().string(from: Date()))"
        try stateStore.save(state)
        return sandboxSettingsSnapshot()
    }

    private func statusSnapshot() -> LocalConnectorStatus {
        .init(
            configured: state.deviceID != nil && (try? accessToken()) != nil,
            connectorRunning: gatewayConnected,
            developerMode: state.developerMode,
            cloudBaseURL: configuration.gatewayBaseURL.absoluteString,
            userServiceBaseURL: configuration.gatewayBaseURL.absoluteString,
            deviceID: state.deviceID,
            deviceName: state.deviceName,
            user: state.user,
            defaultWorkspaceID: state.workspaces.first?.id,
            workspaces: state.workspaces
        )
    }

    private func runtimeSettingsSnapshot() -> LocalConnectorRuntimeSettings {
        .init(
            developerMode: state.developerMode,
            developerCloudBaseURL: configuration.gatewayBaseURL.absoluteString,
            developerUserServiceBaseURL: configuration.gatewayBaseURL.absoluteString,
            developerChatOSWebURL: ""
        )
    }

    private func sandboxSettingsSnapshot() -> LocalConnectorSandboxSettings {
        .init(
            enabled: state.sandboxEnabled,
            defaultBackend: "native-macos",
            defaultPermissionProfileID: state.permissionProfileID,
            defaultPermissionProfileName: state.permissionProfileID,
            defaultApprovalPolicy: state.approvalPolicy,
            defaultApprovalReviewer: state.approvalReviewer,
            defaultNetworkAccess: state.networkAccess,
            permissionConfigurationError: nil,
            policyRevision: state.policyRevision
        )
    }

    private func ensureDefaultWorkspace(
        token: String,
        deviceID: String,
        publicKey: String
    ) async throws -> LocalConnectorWorkspace {
        let root = "/"
        let digest = SHA256.hash(data: Data("\(root)\u{0}\(publicKey)".utf8))
        let fingerprint = digest.map { String(format: "%02x", $0) }.joined()
        let existing = try await gateway.listWorkspaces(token: token).first {
            $0.deviceID == deviceID && $0.localPathFingerprint == fingerprint
        }
        let remote: GatewayWorkspaceDTO
        if let existing {
            remote = existing
        } else {
            remote = try await gateway.createWorkspace(
                token: token,
                deviceID: deviceID,
                alias: "本机文件系统",
                fingerprint: fingerprint
            )
        }
        return .init(
            id: remote.id,
            alias: remote.localPathAlias,
            absoluteRoot: root,
            fingerprint: remote.localPathFingerprint
        )
    }

    private func connectGateway() async throws {
        guard webSocket == nil else { return }
        let token = try requireAccessToken()
        guard let deviceID = state.deviceID else { throw NativeConnectorError.notPaired }
        let identity = try deviceIdentity()
        let path = "/api/local-connectors/devices/\(deviceID)/connect"
        let base = configuration.gatewayBaseURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: base + path) else {
            throw NativeConnectorError.invalidEndpoint
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        guard let url = components.url else { throw NativeConnectorError.invalidEndpoint }
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString
        let payload = NativeConnectorDeviceAuthentication.connectionPayload(
            deviceID: deviceID,
            timestamp: timestamp,
            nonce: nonce,
            path: path
        )
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(deviceID, forHTTPHeaderField: "x-local-connector-device-id")
        request.setValue(timestamp, forHTTPHeaderField: "x-local-connector-device-timestamp")
        request.setValue(nonce, forHTTPHeaderField: "x-local-connector-device-nonce")
        request.setValue(try identity.signature(for: payload), forHTTPHeaderField: "x-local-connector-device-signature")
        request.setValue("ed25519", forHTTPHeaderField: "x-local-connector-device-signature-alg")
        let socket = URLSession.shared.webSocketTask(with: request)
        webSocket = socket
        gatewayConnected = false
        socket.resume()
        receiveTask = Task { [weak self] in await self?.receiveMessages(from: socket) }
        heartbeatTask = Task { [weak self] in await self?.sendHeartbeats(to: socket) }
    }

    private func receiveMessages(from socket: URLSessionWebSocketTask) async {
        do {
            while webSocket != nil {
                let message = try await socket.receive()
                switch message {
                case let .string(text):
                    if let data = text.data(using: .utf8),
                       let envelope = try? JSONDecoder().decode(GatewaySocketEnvelope.self, from: data) {
                        switch envelope.type {
                        case "connected":
                            gatewayConnected = true
                        case "terminal_exec_request":
                            Task { [weak self] in
                                await self?.handleTerminalRelayMessage(data, socket: socket)
                            }
                        case "mcp":
                            Task { [weak self] in
                                await self?.handleMCPRelayMessage(data, socket: socket)
                            }
                        case "workspace_directory_list_request",
                             "workspace_directory_create_request",
                             "workspace_filesystem_request":
                            Task { [weak self] in
                                await self?.handleWorkspaceRelayMessage(data, socket: socket)
                            }
                        default:
                            break
                        }
                    }
                case .data:
                    break
                @unknown default:
                    break
                }
            }
        } catch {
            gatewayConnected = false
            if webSocket === socket { webSocket = nil }
        }
    }

    private func sendHeartbeats(to socket: URLSessionWebSocketTask) async {
        while !Task.isCancelled, webSocket != nil {
            try? await socket.send(.string("{\"type\":\"heartbeat\"}"))
            try? await Task.sleep(for: .seconds(15))
        }
    }

    func publishPluginInstallationStatus() async throws {
        guard let socket = webSocket,
              let ownerUserID = state.user?.id,
              let deviceID = state.deviceID else {
            return
        }
        let records = state.installedPluginRecords ?? [:]
        let items = records.values
            .sorted { $0.pluginID < $1.pluginID }
            .map { record in
                GatewayPluginInstallationStatusItem(
                    ownerUserID: ownerUserID,
                    deviceID: deviceID,
                    pluginID: record.pluginID,
                    releaseID: record.releaseID,
                    version: record.version,
                    artifactSHA256: record.artifactSHA256,
                    platform: Self.pluginPlatform,
                    installStatus: "installed",
                    availabilityStatus: "ready",
                    dependencyStatus: "satisfied",
                    permissionStatus: "satisfied",
                    authStatus: "satisfied",
                    componentStatuses: [],
                    active: state.pluginPreferences[record.pluginID] ?? true
                )
            }
        let data = try JSONEncoder().encode(
            GatewayPluginInstallationStatusMessage(
                type: "plugin_installation_status",
                items: items
            )
        )
        guard let text = String(data: data, encoding: .utf8) else {
            throw NativeConnectorError.invalidResponse("无法编码 Plugin 安装状态")
        }
        try await socket.send(.string(text))
    }

    private static var pluginPlatform: String {
#if arch(arm64)
        "macos-arm64"
#else
        "macos-x64"
#endif
    }

    private func stopGatewayConnection() {
        let continuations = pendingApprovalContinuations.values
        pendingApprovalContinuations.removeAll()
        pendingApprovals.removeAll()
        for continuation in continuations {
            continuation.resume(returning: .deny(reason: "本机连接器已断开。"))
        }
        receiveTask?.cancel()
        heartbeatTask?.cancel()
        receiveTask = nil
        heartbeatTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        gatewayConnected = false
    }

    private func accessToken() throws -> String? {
        if hasLoadedAccessToken { return cachedAccessToken }
        guard let data = try secretStore.load(account: Self.accessTokenAccount) else {
            cachedAccessToken = nil
            hasLoadedAccessToken = true
            return nil
        }
        cachedAccessToken = String(data: data, encoding: .utf8)?.trimmedNonEmpty
        hasLoadedAccessToken = true
        return cachedAccessToken
    }

    func requireAccessToken() throws -> String {
        guard let token = try accessToken() else { throw NativeConnectorError.notPaired }
        return token
    }

    private func deviceIdentity() throws -> NativeConnectorDeviceIdentity {
        if let cachedDeviceIdentity { return cachedDeviceIdentity }
        let identity = try NativeConnectorDeviceIdentity(secretStore: secretStore)
        cachedDeviceIdentity = identity
        return identity
    }
}

private struct GatewaySocketEnvelope: Decodable {
    var type: String
}

private struct GatewayPluginInstallationStatusMessage: Encodable {
    var type: String
    var items: [GatewayPluginInstallationStatusItem]
}

private struct GatewayPluginInstallationStatusItem: Encodable {
    var ownerUserID: String
    var deviceID: String
    var pluginID: String
    var releaseID: String
    var version: String
    var artifactSHA256: String
    var platform: String
    var installStatus: String
    var availabilityStatus: String
    var dependencyStatus: String
    var permissionStatus: String
    var authStatus: String
    var componentStatuses: [String]
    var active: Bool

    enum CodingKeys: String, CodingKey {
        case version, platform, active
        case ownerUserID = "owner_user_id"
        case deviceID = "device_id"
        case pluginID = "plugin_id"
        case releaseID = "release_id"
        case artifactSHA256 = "artifact_sha256"
        case installStatus = "install_status"
        case availabilityStatus = "availability_status"
        case dependencyStatus = "dependency_status"
        case permissionStatus = "permission_status"
        case authStatus = "auth_status"
        case componentStatuses = "component_statuses"
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func prefixText(_ maximum: Int) -> String? {
        guard !isEmpty else { return nil }
        return String(prefix(maximum))
    }
}
