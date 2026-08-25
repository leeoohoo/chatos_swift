import SwiftUI

struct TerminalTabsView: View {
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("test_project").font(.subheadline.weight(.medium))
                Button("关闭", systemImage: "xmark") {}
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 1) }

            Button("新建终端", systemImage: "plus") {}
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct TerminalHeaderView: View {
    @ObservedObject var terminal: TerminalViewModel

    var body: some View {
        HStack {
            Label(terminal.workingDirectory, systemImage: "folder")
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Circle().fill(.green).frame(width: 7, height: 7)
            Text("已连接").font(.caption).foregroundStyle(.secondary)
            StatusCapsule(title: "zsh", color: .secondary)
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }
}

struct TerminalStatusBar: View {
    @ObservedObject var terminal: TerminalViewModel

    var body: some View {
        HStack(spacing: 16) {
            Label("已连接", systemImage: "circle.fill")
                .foregroundStyle(.secondary, .green)
            Text("Local Connector")
            Text("zsh")
            Text("UTF-8")
            Spacer()
            Text(terminal.isRunning ? "命令运行中" : "就绪")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct TerminalLineView: View {
    let line: TerminalOutputLine
    let promptPath: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if line.kind == .command {
                TerminalPromptPrefix(promptPath: promptPath)
            }
            Text(line.text).foregroundStyle(color)
        }
    }

    private var color: Color {
        switch line.kind {
        case .command, .output: .primary
        case .error: .red
        case .success: AppPalette.terminalGreen
        case .system: .secondary
        }
    }
}

struct TerminalPromptView: View {
    @Binding var command: String
    let isRunning: Bool
    let promptPath: String
    let isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            TerminalPromptPrefix(promptPath: promptPath)
            TextField("", text: $command)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .onSubmit(onSubmit)
                .disabled(isRunning)
            if isRunning { ProgressView().controlSize(.small) }
        }
    }
}

private struct TerminalPromptPrefix: View {
    let promptPath: String

    var body: some View {
        Group {
            Text(promptPath).foregroundStyle(Color.accentColor).fontWeight(.semibold)
            Text("%").foregroundStyle(AppPalette.terminalGreen).fontWeight(.bold)
        }
    }
}
