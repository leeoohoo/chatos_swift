import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("ChatOS") {
                    settingsRow(.general)
                    settingsRow(.cloudAI)
                }
                Section("本机连接器") {
                    settingsRow(.connection)
                    settingsRow(.plugins)
                    settingsRow(.approvals)
                    settingsRow(.runtime)
                    settingsRow(.sandbox)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            detail
        }
        .task { activate(selection) }
        .onChange(of: selection) { _, next in
            model.localConnectorControl.clearMessages()
            activate(next)
        }
    }

    private func settingsRow(_ item: SettingsSection) -> some View {
        Label(item.title, systemImage: item.systemImage).tag(item)
    }

    @ViewBuilder
    private var detail: some View {
        if selection == .general {
            generalSettings
        } else {
            VStack(spacing: 0) {
                settingsHeader
                Divider()
                if let error = model.localConnectorControl.errorMessage {
                    banner(error, image: "exclamationmark.triangle.fill", tint: .orange)
                } else if let notice = model.localConnectorControl.notice {
                    banner(notice, image: "checkmark.circle.fill", tint: .green)
                }
                connectorDetail
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var generalSettings: some View {
        Form {
            Section("语言") {
                Picker("界面语言", selection: $model.interfaceLanguage) {
                    Text("中文").tag("中文")
                    Text("English").tag("English")
                }
                Picker("内部上下文语言", selection: $model.contextLanguage) {
                    Text("中文").tag("中文")
                    Text("English").tag("English")
                }
            }
            Section("显示") {
                LabeledContent("界面字体大小") {
                    HStack(spacing: 10) {
                        Image(systemName: "textformat.size.smaller")
                            .foregroundStyle(.secondary)
                        Slider(value: $model.interfaceFontSize, in: 12...18, step: 1)
                            .frame(width: 220)
                        Image(systemName: "textformat.size.larger")
                            .foregroundStyle(.secondary)
                        Text("\(Int(model.interfaceFontSize)) pt")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
                HStack {
                    Text("调整后会立即应用到主界面、项目、Plan、任务详情和设置。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("恢复默认") { model.interfaceFontSize = 14 }
                }
            }
            Section("账号") {
                if case let .authenticated(session) = model.authentication.phase {
                    LabeledContent("当前账号", value: session.user.displayName ?? session.user.username)
                    LabeledContent("角色", value: session.user.role)
                    Button("退出登录", role: .destructive) { model.authentication.logout() }
                } else {
                    Text("尚未登录").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("常规")
        .padding()
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: selection.systemImage)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(selection.eyebrow)
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(selection.title).font(.title2.weight(.semibold))
                Text(selection.description).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if model.localConnectorControl.isLoading
                || model.localConnectorControl.isPerformingAction
                || model.localConnectorControl.isStarting {
                ProgressView().controlSize(.small)
            }
            Button("刷新", systemImage: "arrow.clockwise") {
                model.localConnectorControl.refreshSelectedTab()
            }
            .labelStyle(.iconOnly)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var connectorDetail: some View {
        switch selection {
        case .cloudAI: LocalConnectorModelsView(viewModel: model.localConnectorControl)
        case .connection: LocalConnectorConnectionView(viewModel: model.localConnectorControl)
        case .plugins: LocalConnectorPluginsView(viewModel: model.localConnectorControl)
        case .approvals: LocalConnectorApprovalsView(viewModel: model.localConnectorControl)
        case .runtime: LocalConnectorRuntimePermissionsView(viewModel: model.localConnectorControl)
        case .sandbox: LocalConnectorSandboxView(viewModel: model.localConnectorControl)
        case .general: EmptyView()
        }
    }

    private func activate(_ section: SettingsSection) {
        guard let tab = section.connectorTab else { return }
        model.localConnectorControl.selectedTab = tab
        model.localConnectorControl.refreshSelectedTab()
    }

    private func banner(_ text: String, image: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: image).foregroundStyle(tint)
            Text(text).font(.callout).textSelection(.enabled)
            Spacer()
            Button("关闭", systemImage: "xmark", action: model.localConnectorControl.clearMessages)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(tint.opacity(0.08))
        .overlay(alignment: .bottom) { Divider() }
    }
}

private enum SettingsSection: String, CaseIterable, Hashable {
    case general, cloudAI, connection, plugins, approvals, runtime, sandbox

    var title: String {
        switch self {
        case .general: "常规与账号"
        case .cloudAI: "AI 模型配置"
        case .connection: "设备与网关"
        case .plugins: "插件与 Skills"
        case .approvals: "命令审批"
        case .runtime: "运行与系统权限"
        case .sandbox: "权限控制"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .cloudAI: "sparkles"
        case .connection: "network"
        case .plugins: "puzzlepiece.extension"
        case .approvals: "checkmark.shield"
        case .runtime: "lock.open.display"
        case .sandbox: "shield.lefthalf.filled"
        }
    }

    var eyebrow: String {
        switch self {
        case .cloudAI: "CLOUD AI"
        case .connection: "NATIVE CONNECTOR"
        case .plugins: "PLUGINS & SKILLS"
        case .approvals: "APPROVAL"
        case .runtime: "SYSTEM ACCESS"
        case .sandbox: "PERMISSION POLICY"
        case .general: "SETTINGS"
        }
    }

    var description: String {
        switch self {
        case .general: "管理界面语言与当前账号。"
        case .cloudAI: "管理 ChatOS 云端模型，并选择本机审批模型。"
        case .connection: "管理 Swift Native Connector 的设备身份与网关长连接。"
        case .plugins: "管理运行在这台 Mac 上的 Plugin 与 Skills。"
        case .approvals: "配置敏感命令与 Computer Use 的审批策略。"
        case .runtime: "检查客户端运行状态与 macOS 系统授权。"
        case .sandbox: "配置文件、网络和进程的本机安全边界。"
        }
    }

    var connectorTab: LocalConnectorControlTab? {
        switch self {
        case .general: nil
        case .cloudAI: .models
        case .connection: .connection
        case .plugins: .plugins
        case .approvals: .approvals
        case .runtime: .runtime
        case .sandbox: .sandbox
        }
    }
}
