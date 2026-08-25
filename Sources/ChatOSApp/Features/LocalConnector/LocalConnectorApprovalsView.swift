import ChatOSCore
import SwiftUI

struct LocalConnectorApprovalsView: View {
    @ObservedObject var viewModel: LocalConnectorControlCenterViewModel
    @State private var proposedElevatedMode: LocalConnectorApprovalMode?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                policyCard
                pendingCard
                historyCard
            }
            .padding(24)
        }
        .confirmationDialog(
            approvalConfirmationTitle,
            isPresented: Binding(
                get: { proposedElevatedMode != nil },
                set: { if !$0 { proposedElevatedMode = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let mode = proposedElevatedMode {
                Button(approvalConfirmationButton(for: mode), role: .destructive) {
                    proposedElevatedMode = nil
                    viewModel.updateApprovalMode(mode, riskAcknowledged: true)
                }
            }
            Button("取消", role: .cancel) {
                proposedElevatedMode = nil
            }
        } message: {
            Text(approvalConfirmationMessage)
        }
    }

    private var policyCard: some View {
        LocalConnectorCard(
            "默认审批级别",
            subtitle: "项目没有单独策略时使用这里的默认值",
            systemImage: "checkmark.shield"
        ) {
            Picker(
                "审批模式",
                selection: Binding(
                    get: { viewModel.approvalSettings?.defaultMode ?? .requestApproval },
                    set: { mode in
                        if mode == .requestApproval {
                            viewModel.updateApprovalMode(mode, riskAcknowledged: false)
                        } else {
                            proposedElevatedMode = mode
                        }
                    }
                )
            ) {
                Text("需要确认").tag(LocalConnectorApprovalMode.requestApproval)
                Text("自动审批").tag(LocalConnectorApprovalMode.autoApproval)
                Text("完全控制").tag(LocalConnectorApprovalMode.fullControl)
            }
            .pickerStyle(.segmented)
            Text(approvalModeDescription)
                .appFont(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var pendingCard: some View {
        LocalConnectorCard(
            "等待处理",
            subtitle: "任务会停在这里，直到用户或审批模型作出决定",
            systemImage: "hourglass"
        ) {
            if viewModel.pendingApprovals.isEmpty {
                Label("当前没有等待审批的操作", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.pendingApprovals) { approval in
                        pendingRow(approval)
                        if approval.id != viewModel.pendingApprovals.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func pendingRow(_ approval: LocalConnectorPendingApproval) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(approval.risk.uppercased())
                    .appFont(.caption2.weight(.bold))
                    .foregroundStyle(riskColor(approval.risk))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(riskColor(approval.risk).opacity(0.1), in: Capsule())
                Text(approval.source)
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(approval.createdAt)
                    .appFont(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(approval.command)
                .appFont(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
            Text(approval.cwd)
                .appFont(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let reason = approval.reason, !reason.isEmpty {
                Text(reason)
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("拒绝", role: .destructive) {
                    viewModel.resolveApproval(id: approval.id, decision: "decline")
                }
                Spacer()
                Button("仅本次允许") {
                    viewModel.resolveApproval(id: approval.id, decision: "accept")
                }
                Button("本会话允许") {
                    viewModel.resolveApproval(id: approval.id, decision: "acceptForSession")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 10)
    }

    private var historyCard: some View {
        LocalConnectorCard(
            "审批记录",
            subtitle: "最近的命令和 Computer Use 决策审计",
            systemImage: "clock.arrow.circlepath"
        ) {
            let history = Array((viewModel.approvalSettings?.history ?? []).prefix(30))
            if history.isEmpty {
                Text("还没有审批记录。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: 0) {
                    ForEach(history) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: decisionIcon(entry.decision))
                                .foregroundStyle(decisionColor(entry.decision))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.command)
                                    .appFont(.system(.callout, design: .monospaced))
                                    .lineLimit(2)
                                Text("\(entry.source) · \(entry.createdAt)")
                                    .appFont(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.decision)
                                .appFont(.caption.weight(.medium))
                                .foregroundStyle(decisionColor(entry.decision))
                        }
                        .padding(.vertical, 8)
                        if entry.id != history.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private var approvalModeDescription: String {
        switch viewModel.approvalSettings?.defaultMode ?? .requestApproval {
        case .requestApproval: "敏感操作逐条确认；这是默认推荐策略。"
        case .autoApproval: "由审批模型根据操作风险自动决定，无法判断时仍会询问用户。"
        case .fullControl: "允许任务直接执行高风险操作，只适合完全受信任的环境。"
        }
    }

    private var approvalConfirmationTitle: String {
        switch proposedElevatedMode {
        case .autoApproval: "确认启用自动审批？"
        case .fullControl: "确认授予完全控制？"
        default: "确认更改审批模式？"
        }
    }

    private var approvalConfirmationMessage: String {
        switch proposedElevatedMode {
        case .autoApproval:
            "审批模型将自动决定部分敏感操作，无法判断时仍会请求你的确认。"
        case .fullControl:
            "任务将可以直接执行高风险操作。请只在完全信任当前设备、项目与任务时使用。"
        default:
            "此操作会改变本机任务的默认审批策略。"
        }
    }

    private func approvalConfirmationButton(for mode: LocalConnectorApprovalMode) -> String {
        switch mode {
        case .autoApproval: "启用自动审批"
        case .fullControl: "授予完全控制"
        case .requestApproval: "切换"
        }
    }

    private func riskColor(_ risk: String) -> Color {
        switch risk.lowercased() {
        case "critical", "high": .red
        case "medium": .orange
        default: .blue
        }
    }

    private func decisionIcon(_ decision: String) -> String {
        decision.lowercased().contains("allow") || decision.lowercased().contains("accept")
            ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private func decisionColor(_ decision: String) -> Color {
        decision.lowercased().contains("allow") || decision.lowercased().contains("accept")
            ? .green : .orange
    }
}
