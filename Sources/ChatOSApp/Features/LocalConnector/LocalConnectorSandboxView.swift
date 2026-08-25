import SwiftUI

struct LocalConnectorSandboxView: View {
    @ObservedObject var viewModel: LocalConnectorControlCenterViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                policyCard
                backendCard
            }
            .padding(24)
        }
    }

    private var policyCard: some View {
        LocalConnectorCard(
            "默认任务权限",
            subtitle: "新任务在没有项目级覆盖时使用这套策略",
            systemImage: "lock.shield"
        ) {
            if let settings = viewModel.sandboxSettings {
                Toggle(
                    "启用本机权限控制",
                    isOn: Binding(
                        get: { settings.enabled },
                        set: { viewModel.updateSandbox(enabled: $0) }
                    )
                )
                .toggleStyle(.switch)

                if let error = settings.permissionConfigurationError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .appFont(.caption)
                        .foregroundStyle(.red)
                }

                Divider()
                picker(
                    "文件权限",
                    selection: settings.defaultPermissionProfileID,
                    values: [
                        ("read_only", "只读"),
                        ("workspace_write", "工作区可写"),
                        ("full_access", "完全访问"),
                    ]
                ) { viewModel.updateSandbox(permissionProfileID: $0) }
                picker(
                    "审批策略",
                    selection: settings.defaultApprovalPolicy,
                    values: [("on_request", "按需审批"), ("never", "不请求审批")]
                ) { viewModel.updateSandbox(approvalPolicy: $0) }
                picker(
                    "审批人",
                    selection: settings.defaultApprovalReviewer,
                    values: [("user", "用户"), ("auto_review", "审批模型")]
                ) { viewModel.updateSandbox(approvalReviewer: $0) }
                picker(
                    "网络访问",
                    selection: settings.defaultNetworkAccess,
                    values: [
                        ("disabled", "禁用"),
                        ("controlled", "受控访问"),
                        ("host", "跟随本机"),
                    ]
                ) { viewModel.updateSandbox(networkAccess: $0) }
                Divider()
                LocalConnectorKeyValueRow(label: "当前 Profile", value: settings.defaultPermissionProfileName)
                LocalConnectorKeyValueRow(label: "策略版本", value: settings.policyRevision ?? "—", monospaced: true)
            } else {
                ProgressView("正在读取权限策略…")
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
    }

    private var backendCard: some View {
        LocalConnectorCard(
            "运行后端",
            subtitle: "当前版本只允许使用本机进程后端",
            systemImage: "cpu"
        ) {
            if viewModel.sandboxBackends.isEmpty {
                Text("没有可用的权限执行后端。")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.sandboxBackends) { backend in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: backend.status == "ready" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(backend.status == "ready" ? .green : .orange)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(backend.backend == "local_process" ? "本机进程" : backend.backend)
                                        .appFont(.headline)
                                    Text(backend.status)
                                        .appFont(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Text(backend.message)
                                    .appFont(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    capability("文件隔离", enabled: backend.filesystemIsolation)
                                    capability("网络隔离", enabled: backend.networkIsolation)
                                    capability("进程树控制", enabled: backend.processTreeControl)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private func picker(
        _ label: String,
        selection: String,
        values: [(String, String)],
        onChange: @escaping (String) -> Void
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker(label, selection: Binding(
                get: { selection },
                set: { value in onChange(value) }
            )) {
                ForEach(values, id: \.0) { value, title in
                    Text(title).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 180)
        }
    }

    private func capability(_ label: String, enabled: Bool) -> some View {
        Label(label, systemImage: enabled ? "checkmark" : "minus")
            .appFont(.caption2)
            .foregroundStyle(enabled ? .green : .secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}
