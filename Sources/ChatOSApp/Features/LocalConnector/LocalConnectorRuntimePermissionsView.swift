import ChatOSCore
import SwiftUI

struct LocalConnectorRuntimePermissionsView: View {
    @ObservedObject var viewModel: LocalConnectorControlCenterViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                runtimeCard
                permissionsCard
            }
            .padding(24)
        }
    }

    private var runtimeCard: some View {
        LocalConnectorCard(
            "运行配置",
            subtitle: "开发模式只改变服务端点，不改变本机权限边界",
            systemImage: "slider.horizontal.3"
        ) {
            if let settings = viewModel.runtimeSettings {
                Toggle(
                    "开发者模式",
                    isOn: Binding(
                        get: { settings.developerMode },
                        set: { enabled in
                            viewModel.updateDeveloperMode(enabled)
                        }
                    )
                )
                .toggleStyle(.switch)
                Divider()
                LocalConnectorKeyValueRow(label: "Connector Gateway", value: settings.developerCloudBaseURL, monospaced: true)
                LocalConnectorKeyValueRow(label: "Account Service", value: settings.developerUserServiceBaseURL, monospaced: true)
                Text("Swift Native Connector 直接连接这些服务端点，不启动本机 HTTP Core。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("正在读取运行配置…")
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
    }

    private var permissionsCard: some View {
        LocalConnectorCard(
            "系统权限",
            subtitle: viewModel.systemPermissions.map { "\($0.platformLabel) 下 Skills 与 MCP 的系统访问状态" },
            systemImage: "hand.raised"
        ) {
            if let permissions = viewModel.systemPermissions {
                VStack(spacing: 0) {
                    ForEach(permissions.items) { permission in
                        permissionRow(permission)
                        if permission.id != permissions.items.last?.id { Divider() }
                    }
                }
            } else {
                ProgressView("正在检查系统权限…")
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
    }

    private func permissionRow(_ permission: LocalConnectorSystemPermission) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: permissionIcon(permission.id))
                .font(.system(size: 17))
                .foregroundStyle(permissionColor(permission.status))
                .frame(width: 28, height: 28)
                .background(permissionColor(permission.status).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(permission.label)
                        .font(.headline)
                    Text(permission.statusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(permissionColor(permission.status))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(permissionColor(permission.status).opacity(0.1), in: Capsule())
                }
                Text(permission.summary)
                    .font(.callout)
                if !permission.note.isEmpty {
                    Text(permission.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = permission.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 12)
            if permission.canRequest && !isReady(permission.status) {
                Button(permission.requestLabel) {
                    viewModel.requestPermission(id: permission.id)
                }
                .disabled(viewModel.isPerformingAction)
            }
        }
        .padding(.vertical, 11)
    }

    private func isReady(_ status: String) -> Bool {
        status == "ready" || status == "not_applicable" || status == "on_demand"
    }

    private func permissionColor(_ status: String) -> Color {
        switch status {
        case "ready", "not_applicable", "on_demand": .green
        case "needs_attention", "missing_dependency", "action_required": .orange
        default: .secondary
        }
    }

    private func permissionIcon(_ id: String) -> String {
        if id.contains("accessibility") { return "accessibility" }
        if id.contains("screen") { return "rectangle.inset.filled.and.person.filled" }
        if id.contains("automation") { return "app.badge.checkmark" }
        if id.contains("network") { return "network" }
        if id.contains("folder") || id.contains("file") { return "folder" }
        return "lock.shield"
    }
}
