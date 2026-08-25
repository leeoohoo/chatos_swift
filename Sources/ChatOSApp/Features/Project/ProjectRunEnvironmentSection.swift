import ChatOSCore
import SwiftUI

struct ProjectRunEnvironmentSection: View {
    @ObservedObject var viewModel: ProjectRunSettingsViewModel
    @State private var isAdvancedExpanded = false

    var body: some View {
        SettingsCard(title: "启动所需环境", systemImage: "wrench.and.screwdriver") {
            if let environment = viewModel.environment {
                readinessSummary(environment)

                let kinds = requiredToolchainKinds
                if kinds.isEmpty {
                    Label("这个运行目标不依赖额外的开发工具，可以直接启动。", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    VStack(spacing: 10) {
                        ForEach(kinds, id: \.self) { kind in
                            toolchainRow(kind, environment: environment)
                        }
                    }
                }

                if !kinds.isEmpty {
                    HStack {
                        Text("“自动”会使用上面显示的程序路径。")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(viewModel.isMutating ? "保存中…" : "保存工具选择", systemImage: "square.and.arrow.down") {
                            Task { await viewModel.saveEnvironment() }
                        }
                        .disabled(viewModel.isMutating)
                    }
                }

                Divider()

                DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                    environmentVariablesEditor
                        .padding(.top, 10)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("高级设置：环境变量")
                            .appFont(.subheadline.weight(.semibold))
                        Text("只有项目明确要求 PORT、NODE_ENV 等变量时才需要设置。")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("正在检查本机运行环境…").foregroundStyle(.secondary)
                }
                .frame(minHeight: 54)
            }
        }
    }

    private func readinessSummary(_ environment: ProjectRunEnvironment) -> some View {
        let targetName = viewModel.selectedTarget?.label ?? "当前运行目标"
        let ready = environment.validationIssues.isEmpty
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .appFont(.title3)
                .foregroundStyle(ready ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(ready ? "运行环境已准备好" : "启动前还需要处理环境问题")
                    .appFont(.subheadline.weight(.semibold))
                Text(ready
                     ? "已为“\(targetName)”找到所需的本机工具。通常无需修改下面的自动选择。"
                     : "系统会在本机启动“\(targetName)”。请先处理上方预检提示中缺少的工具。")
                    .appFont(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((ready ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
    }

    private func toolchainRow(_ kind: String, environment: ProjectRunEnvironment) -> some View {
        let options = environment.toolchainOptions[kind] ?? []
        let selectedOption = resolvedOption(kind, environment: environment)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: selectedOption == nil ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(selectedOption == nil ? .red : .green)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(toolchainTitle(kind)).appFont(.subheadline.weight(.semibold))
                    Text(selectedOption == nil ? "未找到" : "已找到")
                        .appFont(.caption.weight(.medium))
                        .foregroundStyle(selectedOption == nil ? .red : .green)
                }
                Text(toolchainDescription(kind))
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                if let selectedOption {
                    Text(selectedOption.path)
                        .appFont(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 12)

            Picker("选择 \(toolchainTitle(kind))", selection: toolchainBinding(kind)) {
                if let automatic = options.first {
                    Text("自动 · \(automatic.label)").tag("")
                } else {
                    Text("未找到可用程序").tag("")
                }
                ForEach(options) { option in
                    Text(optionLabel(option)).tag(option.id)
                }
                if let selected = viewModel.selectedToolchains[kind],
                   !selected.isEmpty,
                   !options.contains(where: { $0.id == selected }) {
                    Text("手动 · \(URL(fileURLWithPath: selected).lastPathComponent)").tag(selected)
                }
            }
            .labelsHidden()
            .frame(width: 220)
        }
        .padding(13)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).stroke(.separator.opacity(0.7)) }
    }

    private var environmentVariablesEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这些值只会传给这台 Mac 上由 ChatOS 启动的项目进程，不会上传到 ChatOS。")
                .appFont(.caption)
                .foregroundStyle(.secondary)

            if viewModel.environmentVariables.isEmpty {
                Text("当前没有自定义环境变量。")
                    .appFont(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach($viewModel.environmentVariables) { $variable in
                HStack {
                    TextField("变量名，例如 PORT", text: $variable.key)
                        .appFont(.body.monospaced())
                        .frame(maxWidth: 260)
                    TextField("值", text: $variable.value)
                        .appFont(.body.monospaced())
                    Button(role: .destructive) {
                        viewModel.removeEnvironmentVariable(id: variable.id)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .help("删除这个环境变量")
                }
            }

            HStack {
                Button("添加环境变量", systemImage: "plus") {
                    viewModel.addEnvironmentVariable()
                }
                Spacer()
                Button(viewModel.isMutating ? "保存中…" : "保存环境变量", systemImage: "square.and.arrow.down") {
                    Task { await viewModel.saveEnvironment() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isMutating)
            }
        }
    }

    private var requiredToolchainKinds: [String] {
        Array(Set(viewModel.selectedTarget?.requiredToolchains ?? [])).sorted()
    }

    private func resolvedOption(_ kind: String, environment: ProjectRunEnvironment) -> ProjectRunToolchainOption? {
        let options = environment.toolchainOptions[kind] ?? []
        guard let selected = viewModel.selectedToolchains[kind], !selected.isEmpty else {
            return options.first
        }
        return options.first(where: { $0.id == selected || $0.path == selected })
            ?? ProjectRunToolchainOption(
                id: selected,
                kind: kind,
                label: URL(fileURLWithPath: selected).lastPathComponent,
                version: nil,
                path: selected,
                source: "手动选择",
                isDefault: false
            )
    }

    private func toolchainBinding(_ kind: String) -> Binding<String> {
        Binding(
            get: { viewModel.selectedToolchains[kind] ?? "" },
            set: { viewModel.selectedToolchains[kind] = $0 }
        )
    }

    private func optionLabel(_ option: ProjectRunToolchainOption) -> String {
        [option.label, option.version].compactMap { $0 }.joined(separator: " · ")
    }

    private func toolchainTitle(_ kind: String) -> String {
        switch kind.lowercased() {
        case "java_home": "JDK"
        case "java": "JDK / Java"
        case "mvn": "Maven"
        case "gradle": "Gradle"
        case "python": "Python"
        case "node": "Node.js"
        case "cargo": "Cargo"
        case "go": "Go"
        case "swift": "Swift"
        default: kind
        }
    }

    private func toolchainDescription(_ kind: String) -> String {
        switch kind.lowercased() {
        case "java", "java_home": "编译并启动 Java 应用"
        case "mvn": "读取 pom.xml、解析依赖并执行 Spring Boot"
        case "gradle": "读取 Gradle 构建配置并启动应用"
        case "node": "运行 JavaScript / TypeScript 代码"
        case "npm", "pnpm", "yarn": "安装依赖并执行 package.json 中的脚本"
        case "python": "运行 Python 程序和测试"
        case "cargo": "编译并运行 Rust 项目"
        case "go": "编译并运行 Go 项目"
        case "swift": "编译并运行 Swift Package"
        default: "当前运行目标需要使用的本机程序"
        }
    }
}
