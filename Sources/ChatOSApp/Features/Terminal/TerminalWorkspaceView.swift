import SwiftUI

struct TerminalWorkspaceView: View {
    @StateObject private var terminal = TerminalViewModel()
    @FocusState private var commandFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TerminalTabsView()
            Divider()
            TerminalHeaderView(terminal: terminal)
            Divider()
            viewport
            Divider()
            TerminalStatusBar(terminal: terminal)
        }
        .navigationTitle("test_project")
        .toolbar { toolbar }
        .onAppear { commandFocused = true }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            TextField("搜索终端输出", text: $terminal.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 190)

            Menu {
                Button("清屏", systemImage: "eraser", action: terminal.clear)
                Button("重新连接", systemImage: "arrow.clockwise") {}
                Divider()
                Button("关闭终端", systemImage: "xmark") {}
                Button("删除终端", systemImage: "trash", role: .destructive) {}
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var viewport: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Button("加载更早输出", systemImage: "arrow.up") {}
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)

                    ForEach(terminal.visibleLines) { line in
                        TerminalLineView(line: line, promptPath: promptPath)
                            .id(line.id)
                    }

                    TerminalPromptView(
                        command: $terminal.command,
                        isRunning: terminal.isRunning,
                        promptPath: promptPath,
                        isFocused: $commandFocused,
                        onSubmit: terminal.submit
                    )
                    .id("prompt")
                }
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: terminal.lines.count) {
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("prompt", anchor: .bottom)
                }
            }
        }
    }

    private var promptPath: String {
        URL(fileURLWithPath: terminal.workingDirectory).lastPathComponent
    }
}
