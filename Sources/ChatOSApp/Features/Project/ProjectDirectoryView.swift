import AppKit
import ChatOSCore
import SwiftUI

struct ProjectDirectoryView: View {
    @StateObject private var viewModel: ProjectDirectoryViewModel
    @State private var createKind: CreateKind?
    @State private var createName = ""

    init(
        projectID: String,
        rootPath: String?,
        service: any ProjectFilesystemServicing,
        codeNavigationService: any ProjectCodeNavigationServicing
    ) {
        _viewModel = StateObject(wrappedValue: ProjectDirectoryViewModel(
            projectID: projectID,
            rootPath: rootPath,
            service: service,
            codeNavigationService: codeNavigationService
        ))
    }

    var body: some View {
        HSplitView {
            browser
                .frame(minWidth: 270, idealWidth: 330, maxWidth: 460)
            ProjectFileEditorView(viewModel: viewModel)
                .frame(minWidth: 520)
        }
        .workspaceFill()
        .task { await viewModel.load() }
        .onChange(of: viewModel.searchText) { _, _ in viewModel.scheduleSearch() }
        .alert("项目目录操作失败", isPresented: errorPresented) {
            Button("好") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .sheet(item: $createKind) { kind in createSheet(kind) }
    }

    private var browser: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("搜索项目文件", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    Button("新建文件", systemImage: "doc.badge.plus") { createKind = .file }
                    Button("新建文件夹", systemImage: "folder.badge.plus") { createKind = .directory }
                } label: { Image(systemName: "plus") }
                    .menuStyle(.borderlessButton)
                Button { Task { await viewModel.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
                    .help("刷新")
            }
            .padding(12)
            Divider()
            if viewModel.rootPath == nil {
                ContentUnavailableView("没有项目目录", systemImage: "folder.badge.questionmark", description: Text("请先为项目连接本机目录。"))
                    .workspaceFill()
            } else if !viewModel.searchText.isEmpty {
                searchResults
            } else {
                tree
            }
        }
        .workspaceFill()
        .background(AppPalette.canvas)
    }

    private var tree: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(viewModel.visibleEntries) { item in
                    ProjectFileTreeRow(item: item, isSelected: viewModel.selectedPath == item.entry.path) {
                        Task { await viewModel.toggle(item.entry) }
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .workspaceFill(alignment: .topLeading)
        .overlay { if viewModel.isLoading && viewModel.visibleEntries.isEmpty { ProgressView() } }
    }

    private var searchResults: some View {
        List {
            if !viewModel.contentSearchResults.isEmpty {
                Section("文件内容") {
                    ForEach(viewModel.contentSearchResults) { match in
                        Button {
                            Task { await viewModel.selectContentSearchResult(match) }
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.magnifyingglass")
                                        .foregroundStyle(.secondary)
                                    Text(URL(fileURLWithPath: match.path).lastPathComponent)
                                        .appFont(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("第 \(match.line) 行")
                                        .appFont(.caption2.monospacedDigit())
                                        .foregroundStyle(AppPalette.ai)
                                }
                                Text(match.text.trimmingCharacters(in: .whitespaces))
                                    .appFont(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(match.displayPath ?? match.path)
                                    .appFont(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !viewModel.searchResults.isEmpty {
                Section("文件和目录") {
                    ForEach(viewModel.searchResults) { entry in
                        Button { Task { await viewModel.selectSearchResult(entry) } } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Label(entry.name, systemImage: entry.isDirectory ? "folder" : "doc.text")
                                Text(entry.displayPath ?? entry.path)
                                    .appFont(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .workspaceFill()
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(AppPalette.canvas)
        .overlay {
            if viewModel.isSearching {
                ProgressView("正在搜索文件内容…")
                    .padding(16)
                    .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay { RoundedRectangle(cornerRadius: 10).stroke(AppPalette.border.opacity(0.8)) }
            } else if viewModel.searchResults.isEmpty && viewModel.contentSearchResults.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }

    private func createSheet(_ kind: CreateKind) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(kind == .file ? "新建文件" : "新建文件夹").appFont(.title2.weight(.semibold))
            TextField(kind == .file ? "例如 README.md" : "文件夹名称", text: $createName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { createKind = nil; createName = "" }
                Button("创建") {
                    let name = createName.trimmingCharacters(in: .whitespacesAndNewlines)
                    createKind = nil
                    createName = ""
                    Task { await viewModel.create(name: name, directory: kind == .directory) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(createName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.dismissError() } })
    }
}

private enum CreateKind: String, Identifiable { case file, directory; var id: String { rawValue } }

private struct ProjectFileTreeRow: View {
    let item: ProjectDirectoryViewModel.VisibleEntry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if item.entry.isDirectory {
                    Image(systemName: item.isExpanded ? "chevron.down" : "chevron.right")
                        .appFont(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear.frame(width: 10, height: 10)
                }
                Image(systemName: item.entry.isDirectory ? "folder.fill" : fileIcon)
                    .foregroundStyle(item.entry.isDirectory ? Color.accentColor : .secondary)
                Text(item.entry.name).lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.leading, CGFloat(item.depth) * 18 + 9)
            .padding(.trailing, 8)
            .frame(height: 28)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 5)
    }

    private var fileIcon: String {
        switch URL(fileURLWithPath: item.entry.name).pathExtension.lowercased() {
        case "swift": "swift"
        case "md", "markdown": "doc.richtext"
        case "json", "yaml", "yml", "toml": "curlybraces"
        case "png", "jpg", "jpeg", "gif", "webp": "photo"
        default: "doc.text"
        }
    }
}
