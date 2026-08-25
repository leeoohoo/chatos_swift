import ChatOSCore
import SwiftUI

struct ProjectRunSettingsView: View {
    @StateObject private var viewModel: ProjectRunSettingsViewModel
    let projectName: String
    let rootPath: String?

    init(projectID: String, projectName: String, rootPath: String?, service: any ProjectRunServicing) {
        self.projectName = projectName
        self.rootPath = rootPath
        _viewModel = StateObject(wrappedValue: ProjectRunSettingsViewModel(projectID: projectID, service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader
                if let error = viewModel.catalog?.errorMessage { notice(error, color: .red, icon: "exclamationmark.triangle.fill") }
                if let error = viewModel.errorMessage { notice(error, color: .red, icon: "exclamationmark.triangle.fill") }
                if let message = viewModel.message { notice(message, color: .green, icon: "checkmark.circle.fill") }
                preflightSection
                targetsSection
                ProjectRunInstancesSection(viewModel: viewModel)
                ProjectRunEnvironmentSection(viewModel: viewModel)
                configurationFilesSection
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .workspaceFill(alignment: .top)
        .task {
            await viewModel.load()
            await viewModel.monitorRuns()
        }
        .overlay { if viewModel.isLoading { ProgressView().controlSize(.large) } }
    }

    private var pageHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(projectName).appFont(.title2.weight(.semibold))
                Text(rootPath ?? "未配置项目目录").appFont(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                HStack {
                    StatusCapsule(title: runStatusTitle, color: runStatusColor)
                    StatusCapsule(title: "运行目标 \(viewModel.targets.count)", color: .secondary)
                }
            }
            Spacer()
            Button("重新分析", systemImage: "wand.and.stars") { Task { await viewModel.analyze() } }
                .disabled(viewModel.isMutating)
            Button("刷新", systemImage: "arrow.clockwise") { Task { await viewModel.load() } }
                .disabled(viewModel.isLoading || viewModel.isMutating)
        }
    }

    private var preflightSection: some View {
        SettingsCard(title: "运行预检", systemImage: "checklist") {
            let issues = viewModel.environment?.validationIssues ?? []
            if issues.isEmpty {
                Label("没有发现阻塞问题", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                ForEach(issues) { issue in
                    VStack(alignment: .leading, spacing: 5) {
                        Label(issue.message, systemImage: issue.kind == "warning" ? "exclamationmark.triangle" : "xmark.octagon")
                            .foregroundStyle(issue.kind == "warning" ? .orange : .red)
                        if let path = issue.path { Text(path).appFont(.caption.monospaced()).foregroundStyle(.secondary) }
                        if let hint = issue.hint { Text(hint).appFont(.caption).foregroundStyle(.secondary) }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private var targetsSection: some View {
        SettingsCard(title: "运行目标", systemImage: "play.rectangle") {
            if viewModel.targets.isEmpty {
                ContentUnavailableView("没有识别到运行目标", systemImage: "play.slash", description: Text("点击“重新分析”扫描项目入口和清单文件。"))
                    .frame(minHeight: 130)
            } else {
                Picker("默认目标", selection: targetBinding) {
                    ForEach(viewModel.targets) { target in Text(target.label).tag(Optional(target.id)) }
                }
                if let target = viewModel.selectedTarget {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 9) {
                        settingRow("命令", target.command)
                        settingRow("工作目录", target.cwd)
                        if let language = target.language { settingRow("语言", language) }
                        settingRow("来源", target.source)
                        if let manifest = target.manifestPath { settingRow("清单", manifest) }
                        if let entrypoint = target.entrypoint { settingRow("入口", entrypoint) }
                    }
                    .appFont(.caption)
                    .textSelection(.enabled)
                    HStack {
                        Spacer()
                        Button(viewModel.isMutating ? "启动中…" : "启动新实例", systemImage: "play.fill") { Task { await viewModel.start() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isMutating || !(viewModel.environment?.validationIssues.isEmpty ?? true))
                    }
                }
            }
        }
    }

    private var configurationFilesSection: some View {
        SettingsCard(title: "项目配置文件", systemImage: "doc.text.magnifyingglass") {
            let files = viewModel.environment?.configurationFiles ?? []
            if files.isEmpty {
                Text("没有发现与当前运行目标相关的配置文件。").foregroundStyle(.secondary)
            } else {
                ForEach(files) { file in
                    DisclosureGroup {
                        if let preview = file.preview, !preview.isEmpty {
                            Text(preview).appFont(.caption.monospaced()).textSelection(.enabled).padding(.top, 8)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(file.label).appFont(.subheadline.weight(.semibold))
                            Text(file.path).appFont(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func notice(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var targetBinding: Binding<String?> {
        Binding(get: { viewModel.selectedTargetID }, set: { value in Task { await viewModel.selectTarget(value) } })
    }

    private func settingRow(_ title: String, _ value: String) -> some View {
        GridRow { Text(title).foregroundStyle(.secondary); Text(value).appFont(.caption.monospaced()) }
    }

    private var runStatusTitle: String { localizedRunStatus(viewModel.state?.status ?? viewModel.catalog?.status ?? "loading") }
    private var runStatusColor: Color { viewModel.state?.isRunning == true ? .green : .secondary }
    private func localizedRunStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "running": "运行中"
        case "ready": "就绪"
        case "stopped", "exited": "已停止"
        case "error", "failed": "异常"
        case "idle": "空闲"
        case "loading": "加载中"
        default: status
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage).appFont(.headline)
            content()
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).stroke(AppPalette.border.opacity(0.78), lineWidth: 1) }
    }
}
