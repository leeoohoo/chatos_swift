import Foundation

public struct LocalConnectorSandboxBackend: Codable, Identifiable, Sendable, Equatable {
    public var backend: String
    public var status: String
    public var selectable: Bool
    public var filesystemIsolation: Bool
    public var networkIsolation: Bool
    public var processTreeControl: Bool
    public var message: String

    public var id: String { backend }

    public init(
        backend: String,
        status: String,
        selectable: Bool,
        filesystemIsolation: Bool,
        networkIsolation: Bool,
        processTreeControl: Bool,
        message: String
    ) {
        self.backend = backend
        self.status = status
        self.selectable = selectable
        self.filesystemIsolation = filesystemIsolation
        self.networkIsolation = networkIsolation
        self.processTreeControl = processTreeControl
        self.message = message
    }
}

public struct LocalConnectorSandboxSettings: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var defaultBackend: String
    public var defaultPermissionProfileID: String
    public var defaultPermissionProfileName: String
    public var defaultApprovalPolicy: String
    public var defaultApprovalReviewer: String
    public var defaultNetworkAccess: String
    public var permissionConfigurationError: String?
    public var policyRevision: String?

    public init(
        enabled: Bool,
        defaultBackend: String,
        defaultPermissionProfileID: String,
        defaultPermissionProfileName: String,
        defaultApprovalPolicy: String,
        defaultApprovalReviewer: String,
        defaultNetworkAccess: String,
        permissionConfigurationError: String?,
        policyRevision: String?
    ) {
        self.enabled = enabled
        self.defaultBackend = defaultBackend
        self.defaultPermissionProfileID = defaultPermissionProfileID
        self.defaultPermissionProfileName = defaultPermissionProfileName
        self.defaultApprovalPolicy = defaultApprovalPolicy
        self.defaultApprovalReviewer = defaultApprovalReviewer
        self.defaultNetworkAccess = defaultNetworkAccess
        self.permissionConfigurationError = permissionConfigurationError
        self.policyRevision = policyRevision
    }
}

public struct LocalConnectorPlugin: Codable, Identifiable, Sendable, Equatable {
    public var pluginID: String
    public var displayName: String
    public var description: String
    public var category: String
    public var publisher: String
    public var latestVersion: String
    public var installed: Bool
    public var updateAvailable: Bool
    public var installAvailable: Bool
    public var enabled: Bool

    public var id: String { pluginID }

    public init(
        pluginID: String,
        displayName: String,
        description: String,
        category: String,
        publisher: String,
        latestVersion: String,
        installed: Bool,
        updateAvailable: Bool,
        installAvailable: Bool,
        enabled: Bool
    ) {
        self.pluginID = pluginID
        self.displayName = displayName
        self.description = description
        self.category = category
        self.publisher = publisher
        self.latestVersion = latestVersion
        self.installed = installed
        self.updateAvailable = updateAvailable
        self.installAvailable = installAvailable
        self.enabled = enabled
    }
}
