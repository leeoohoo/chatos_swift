import AppKit
import ChatOSCore
import SwiftUI

struct ProjectFileEditorView: View {
    @ObservedObject var viewModel: ProjectDirectoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let file = viewModel.selectedFile {
                header(file)
                Divider()
                if shouldShowCodeNavigation(for: file) {
                    codeNavigationPanel
                    Divider()
                }
                content(file)
            } else {
                ContentUnavailableView("选择一个文件", systemImage: "doc.text.magnifyingglass", description: Text("从左侧项目目录中选择文件以预览或编辑。"))
                    .workspaceFill()
            }
        }
        .workspaceFill()
    }

    private func shouldShowCodeNavigation(for file: ProjectFileContent) -> Bool {
        guard !file.isBinary else { return false }
        return viewModel.selectedSymbol != nil
            || viewModel.navigationResult != nil
            || viewModel.navigationError != nil
            || viewModel.canNavigateBack
    }

    private var codeNavigationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let symbol = viewModel.selectedSymbol {
                    Label(symbol.token, systemImage: "scope")
                        .font(.caption.monospaced().weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                }

                Button("转到定义", systemImage: "arrow.turn.down.right") {
                    Task { await viewModel.requestNavigation(.definition) }
                }
                .disabled(viewModel.selectedSymbol == nil || viewModel.isNavigating)

                Button("查找引用", systemImage: "point.3.connected.trianglepath.dotted") {
                    Task { await viewModel.requestNavigation(.references) }
                }
                .disabled(viewModel.selectedSymbol == nil || viewModel.isNavigating)

                Button("返回", systemImage: "chevron.backward") {
                    Task { await viewModel.navigateBack() }
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!viewModel.canNavigateBack || viewModel.isNavigating)
                .help("返回上一个位置（⌘[）")

                if viewModel.isNavigating { ProgressView().controlSize(.small) }
                Spacer()

                if let result = viewModel.navigationResult,
                   let kind = viewModel.navigationRequestKind {
                    Text("\(kind.rawValue) · \(result.locations.count) 处 · \(localizedMode(result.mode))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.clearNavigationResults()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("关闭代码导航")
            }

            if let error = viewModel.navigationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let locations = viewModel.navigationResult?.locations, !locations.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(locations) { location in
                            Button {
                                Task { await viewModel.openNavigationLocation(location) }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.top, 1)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(location.relativePath) · 第 \(location.line) 行")
                                            .font(.caption.weight(.semibold))
                                        Text(location.preview.trimmingCharacters(in: .whitespaces))
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if location.id != locations.last?.id { Divider() }
                        }
                    }
                }
                .frame(maxHeight: 180)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func localizedMode(_ mode: String) -> String {
        switch mode {
        case "heuristic": "智能定位"
        case "text-search": "全文符号搜索"
        default: mode
        }
    }

    private func header(_ file: ProjectFileContent) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(file.name).font(.headline)
                Text(file.path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if viewModel.isEditing {
                Button("取消") { viewModel.cancelEditing() }
                Button(viewModel.isSaving ? "保存中…" : "保存", systemImage: "square.and.arrow.down") {
                    Task { await viewModel.save() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSaving)
            } else {
                Button("复制", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(file.content, forType: .string)
                }
                Menu {
                    Button("在 Finder 中显示", systemImage: "folder") { Task { await viewModel.openSelected(mode: .reveal) } }
                    Button("使用默认应用打开", systemImage: "arrow.up.forward.app") { Task { await viewModel.openSelected(mode: .default) } }
                    Divider()
                    Button("删除", systemImage: "trash", role: .destructive) { Task { await viewModel.deleteSelected() } }
                } label: { Image(systemName: "ellipsis.circle") }
                if file.isWritable && !file.isBinary {
                    Button("编辑", systemImage: "pencil") { viewModel.beginEditing() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private func content(_ file: ProjectFileContent) -> some View {
        if file.isBinary {
            ContentUnavailableView("二进制文件", systemImage: "doc.zipper", description: Text("此文件不能在文本编辑器中显示。"))
                .workspaceFill()
        } else if viewModel.isEditing {
            CodeEditorView(
                text: $viewModel.draft,
                fileName: file.name,
                targetLine: viewModel.selectedLine,
                onSymbolSelection: viewModel.selectSymbol
            )
        } else {
            if ["md", "markdown"].contains(URL(fileURLWithPath: file.name).pathExtension.lowercased()),
               viewModel.selectedLine == nil {
                ScrollView {
                    MarkdownDocumentView(markdown: file.content)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                CodePreviewView(
                    content: file.content,
                    fileName: file.name,
                    targetLine: viewModel.selectedLine,
                    onSymbolSelection: viewModel.selectSymbol
                )
            }
        }
    }
}
