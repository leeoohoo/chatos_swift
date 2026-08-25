import ChatOSCore
import SwiftUI

struct LocalConnectorConnectionView: View {
    @ObservedObject var viewModel: LocalConnectorControlCenterViewModel

    var body: some View {
        ScrollView {
            if let status = viewModel.status {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    connectionCard(status)
                    boundaryCard(status)
                }
                .padding(24)
            } else {
                ContentUnavailableView {
                    Label("正在启动本机连接", systemImage: "externaldrive.badge.timemachine")
                } description: {
                    Text("Swift Native Connector 正在读取设备身份并连接网关。")
                } actions: {
                    Button("重试") { viewModel.activate(pairIfNeeded: true) }
                }
                .frame(maxWidth: .infinity, minHeight: 420)
            }
        }
    }

    private func connectionCard(_ status: LocalConnectorStatus) -> some View {
        LocalConnectorCard(
            "连接状态",
            subtitle: viewModel.isStarting ? "正在启动 Swift Native Connector" : statusText(status),
            systemImage: "externaldrive.connected.to.line.below"
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(status.connectorRunning ? .green : .orange)
                        .frame(width: 10, height: 10)
                    Text(status.connectorRunning ? "网关长连接正常" : status.configured ? "已配对，正在等待网关" : "尚未配对")
                        .appFont(.headline)
                    Spacer()
                }
                Divider()
                LocalConnectorKeyValueRow(label: "用户", value: status.user?.username ?? "—")
                LocalConnectorKeyValueRow(label: "设备", value: status.deviceName ?? "—")
                LocalConnectorKeyValueRow(label: "Device ID", value: status.deviceID ?? "—", monospaced: true)
                LocalConnectorKeyValueRow(label: "网关", value: status.cloudBaseURL ?? "—", monospaced: true)
                HStack {
                    if status.configured {
                        Button("断开配对", role: .destructive) { viewModel.disconnect() }
                    } else {
                        Button("连接网关") { viewModel.reconnect() }
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                    Button("刷新状态") { viewModel.refreshStatus() }
                }
                .padding(.top, 4)
            }
        }
    }

    private func boundaryCard(_ status: LocalConnectorStatus) -> some View {
        LocalConnectorCard(
            "本机边界",
            subtitle: "文件、终端和权限策略只在当前设备执行",
            systemImage: "lock.laptopcomputer"
        ) {
            VStack(alignment: .leading, spacing: 13) {
                boundaryRow("文件路由", value: status.workspaces.isEmpty ? "尚无工作区" : "\(status.workspaces.count) 个工作区", image: "folder")
                boundaryRow("权限控制", value: "由 Swift Native Connector 强制执行", image: "lock.shield")
                boundaryRow("运行方式", value: "原生 Swift 本机进程", image: "cpu")
                boundaryRow("开发环境", value: status.developerMode ? "已开启" : "已关闭", image: "hammer")
                Divider()
                Text("云端请求必须先经过设备签名、工作区边界与命令审批；展示层不会直接访问文件或执行命令。")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func boundaryRow(_ label: String, value: String, image: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: image)
                .foregroundStyle(.green)
                .frame(width: 18)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .appFont(.callout)
    }

    private func statusText(_ status: LocalConnectorStatus) -> String {
        if status.connectorRunning { return "已通过网关连接到 ChatOS" }
        return status.configured ? "本机配置有效，长连接暂未建立" : "需要使用当前 ChatOS 登录态完成配对"
    }
}
