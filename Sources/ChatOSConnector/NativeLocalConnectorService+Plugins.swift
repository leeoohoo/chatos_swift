import ChatOSCore
import Foundation

extension NativeLocalConnectorService {
    public func fetchPlugins() async throws -> [LocalConnectorPlugin] {
        let token = try requireAccessToken()
        let sources = try await gateway.pluginSources(token: token)
        return sources.items.map { source in
            let id = source.catalog.id
            let installedRecord = state.installedPluginRecords?[id]
            let installed = installedRecord != nil || state.installedPluginIDs.contains(id)
            return .init(
                pluginID: id,
                displayName: source.catalog.displayName ?? source.catalog.name ?? id,
                description: source.catalog.description ?? "",
                category: source.catalog.interface?.category ?? "Plugin",
                publisher: source.catalog.publisher?.name
                    ?? source.catalog.interface?.developerName
                    ?? "ChatOS",
                latestVersion: source.release.version ?? source.release.id,
                installed: installed,
                updateAvailable: installedRecord.map { $0.version != source.release.version } ?? false,
                installAvailable: source.release.artifactSHA256 != nil
                    && source.release.npmPackage != nil,
                enabled: state.pluginPreferences[id] ?? source.preference?.enabled ?? true
            )
        }
    }

    public func installPlugin(id: String) async throws {
        let token = try requireAccessToken()
        let sources = try await gateway.pluginSources(token: token)
        guard let source = sources.items.first(where: { $0.catalog.id == id }) else {
            throw NativeConnectorError.pluginInstallation("Marketplace 中没有找到这个 Plugin")
        }
        let record = try await pluginInstaller.install(source: source, token: token, gateway: gateway)
        var records = state.installedPluginRecords ?? [:]
        records[id] = record
        state.installedPluginRecords = records
        state.installedPluginIDs.insert(id)
        try stateStore.save(state)
        try? await publishPluginInstallationStatus()
    }

    public func uninstallPlugin(id: String) async throws {
        try pluginInstaller.uninstall(pluginID: id)
        state.installedPluginIDs.remove(id)
        state.installedPluginRecords?[id] = nil
        try stateStore.save(state)
        try? await publishPluginInstallationStatus()
    }

    public func updatePluginEnabled(id: String, enabled: Bool) async throws {
        let token = try requireAccessToken()
        guard let deviceID = state.deviceID else { throw NativeConnectorError.notPaired }
        try await gateway.updatePluginPreference(
            token: token,
            pluginID: id,
            deviceID: deviceID,
            enabled: enabled
        )
        state.pluginPreferences[id] = enabled
        try stateStore.save(state)
        try? await publishPluginInstallationStatus()
    }
}
