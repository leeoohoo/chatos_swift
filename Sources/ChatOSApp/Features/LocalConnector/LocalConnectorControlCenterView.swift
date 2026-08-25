import SwiftUI

struct LocalConnectorControlCenterView: View {
    @ObservedObject var viewModel: LocalConnectorControlCenterViewModel

    var body: some View {
        HSplitView {
            navigation
                .frame(minWidth: 190, idealWidth: 210, maxWidth: 240)
            content
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
        }
        .workspaceFill()
        .navigationTitle("本机控制中心")
        .task {
            viewModel.refreshSelectedTab()
        }
        .onChange(of: viewModel.selectedTab) {
            viewModel.clearMessages()
            viewModel.refreshSelectedTab()
        }
    }

    private var navigation: some View {
        List(selection: $viewModel.selectedTab) {
            Section("控制中心") {
                ForEach(LocalConnectorControlTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
        }
        .workspaceFill()
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text("SWIFT CONNECTOR")
                        .appFont(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    Text(connectionLabel)
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(.bar)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = viewModel.errorMessage {
                messageBanner(error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
            } else if let notice = viewModel.notice {
                messageBanner(notice, systemImage: "checkmark.circle.fill", tint: .green)
            }
            Group {
                switch viewModel.selectedTab {
                case .connection:
                    LocalConnectorConnectionView(viewModel: viewModel)
                case .plugins:
                    LocalConnectorPluginsView(viewModel: viewModel)
                case .terminal:
                    LocalConnectorTerminalView(viewModel: viewModel)
                case .models:
                    LocalConnectorModelsView(viewModel: viewModel)
                case .approvals:
                    LocalConnectorApprovalsView(viewModel: viewModel)
                case .runtime:
                    LocalConnectorRuntimePermissionsView(viewModel: viewModel)
                case .sandbox:
                    LocalConnectorSandboxView(viewModel: viewModel)
                }
            }
            .workspaceFill()
        }
        .workspaceFill()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: viewModel.selectedTab.systemImage)
                .appFont(.system(size: 21, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.selectedTab.eyebrow)
                    .appFont(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedTab.rawValue)
                    .appFont(.title2.weight(.semibold))
                Text(viewModel.selectedTab.description)
                    .appFont(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.isLoading || viewModel.isPerformingAction || viewModel.isStarting {
                ProgressView()
                    .controlSize(.small)
            }
            Button("刷新", systemImage: "arrow.clockwise") {
                viewModel.refreshSelectedTab()
            }
            .labelStyle(.iconOnly)
            .help("刷新当前页面")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private func messageBanner(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .appFont(.callout)
                .textSelection(.enabled)
            Spacer()
            Button("关闭", systemImage: "xmark", action: viewModel.clearMessages)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(tint.opacity(0.08))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var connectionColor: Color {
        guard let status = viewModel.status else { return .secondary }
        return status.connectorRunning ? .green : status.configured ? .orange : .secondary
    }

    private var connectionLabel: String {
        guard let status = viewModel.status else { return "正在启动" }
        if status.connectorRunning { return "连接正常" }
        return status.configured ? "等待网关" : "等待配对"
    }
}

struct LocalConnectorCard<Content: View>: View {
    var title: String
    var subtitle: String?
    var systemImage: String
    @ViewBuilder var content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .appFont(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            content
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.65), lineWidth: 1)
        }
    }
}

struct LocalConnectorKeyValueRow: View {
    var label: String
    var value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 20)
            Text(value)
                .appFont(monospaced ? .system(.callout, design: .monospaced) : .callout)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
