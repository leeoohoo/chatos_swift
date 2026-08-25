import ChatOSCore
import SwiftUI

struct MessageTaskInspectorView: View {
    @ObservedObject var viewModel: MessageTaskWorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader
            Divider()
            if let task = viewModel.taskDetail ?? viewModel.selectedTask {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch viewModel.inspectorSection {
                        case .detail:
                            detail(task)
                        case .process:
                            process(task)
                        case .run:
                            run(task)
                        }
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "选择任务节点",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("选择图中的节点后，可查看过程、详情和运行记录。")
                )
            }
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
        .frame(maxHeight: .infinity)
        .background(AppPalette.canvas)
        .onChange(of: viewModel.inspectorSection) {
            viewModel.ensureInspectorSectionLoaded()
        }
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("任务检查器").appFont(.headline)
                Spacer()
                if viewModel.isLoadingInspector { ProgressView().controlSize(.small) }
            }
            Picker("检查内容", selection: $viewModel.inspectorSection) {
                ForEach(MessageTaskWorkspaceViewModel.InspectorSection.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(16)
    }

    @ViewBuilder
    private func detail(_ task: MessageTask) -> some View {
        TaskInspectorTitle(task: task)
        MessageTaskDetailSections(
            task: task,
            isLoadingModelOutput: viewModel.isLoadingModelOutput
        )
        if task.normalizedStatus == "blocked" || task.normalizedStatus == "failed" {
            blockedActions(task)
        }
    }

    @ViewBuilder
    private func process(_ task: MessageTask) -> some View {
        TaskInspectorTitle(task: task)
        TaskProcessTimelineView(
            items: TaskProcessTimelineBuilder.build(
                processLog: task.processLog,
                taskStatus: task.status
            )
        )
    }

    @ViewBuilder
    private func run(_ task: MessageTask) -> some View {
        TaskInspectorTitle(task: task)
        if viewModel.isLoadingRun && viewModel.runDetail == nil {
            ProgressView("正在加载运行详情…")
        } else if let detail = viewModel.runDetail {
            if let output = detail.run.reportContent {
                TaskDetailTextCard(title: "模型输出", text: output)
            }
            if let summary = detail.run.resultSummary,
               summary.trimmingCharacters(in: .whitespacesAndNewlines)
                != detail.run.reportContent?.trimmingCharacters(in: .whitespacesAndNewlines) {
                TaskDetailTextCard(title: "运行结果摘要", text: summary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("运行信息").appFont(.subheadline.weight(.semibold))
                LabeledContent("状态", value: detail.run.status ?? "未知")
                LabeledContent("运行 ID", value: detail.run.id)
                if let startedAt = detail.run.startedAt {
                    LabeledContent("开始时间") { Text(startedAt, style: .date) + Text(" ") + Text(startedAt, style: .time) }
                }
                if let finishedAt = detail.run.finishedAt {
                    LabeledContent("结束时间") { Text(finishedAt, style: .date) + Text(" ") + Text(finishedAt, style: .time) }
                }
                if let error = detail.run.errorMessage { textSection("错误", error) }
            }
            if !detail.events.isEmpty {
                TaskRunEventTimeline(events: detail.events)
                if detail.eventsHasMore {
                    Button {
                        viewModel.loadMoreRunEvents()
                    } label: {
                        if viewModel.isLoadingMoreRunEvents {
                            ProgressView().controlSize(.small)
                            Text("正在加载…")
                        } else {
                            Text("加载更多运行事件（剩余 \(max(detail.eventsTotal - detail.events.count, 0))）")
                        }
                    }
                    .disabled(viewModel.isLoadingMoreRunEvents)
                }
            } else {
                ContentUnavailableView(
                    "暂无运行事件",
                    systemImage: "list.bullet.clipboard",
                    description: Text("该次运行尚未写入诊断事件。")
                )
            }
        } else if task.lastRunID == nil {
            ContentUnavailableView(
                "暂无运行记录",
                systemImage: "play.slash",
                description: Text("该任务节点尚未产生 Task Runner Run。")
            )
        } else {
            Button("加载运行详情", systemImage: "arrow.down.circle") {
                viewModel.ensureInspectorSectionLoaded()
            }
        }
    }

    private func blockedActions(_ task: MessageTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("处理阻塞", systemImage: "exclamationmark.triangle")
                .appFont(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text("补充本次重试需要遵循的说明；提交后会调用原 Rust 后端的 Task Runner 重试接口。")
                .appFont(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $viewModel.retryInstruction)
                .appFont(.body)
                .frame(minHeight: 72)
                .overlay { RoundedRectangle(cornerRadius: 7).stroke(.separator) }
            Button("重新运行", systemImage: "arrow.clockwise") {
                viewModel.retrySelectedRun()
            }
            .buttonStyle(.borderedProminent)
            .disabled(task.lastRunID == nil || viewModel.isRetrying)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func textSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).appFont(.subheadline.weight(.semibold))
            Text(text)
                .appFont(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
