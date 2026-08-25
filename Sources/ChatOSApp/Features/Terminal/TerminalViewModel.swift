import Foundation
import SwiftUI

@MainActor
final class TerminalViewModel: ObservableObject {
    @Published var command = ""
    @Published var searchText = ""
    @Published var isRunning = false
    @Published var lines: [TerminalOutputLine] = [
        .init(text: "Last login: today on ChatOS local terminal", kind: .system),
        .init(text: "swift --version", kind: .command),
        .init(text: "Apple Swift version 6.3.3", kind: .output),
        .init(text: "Ready.", kind: .success),
    ]

    let workingDirectory: String
    private let executor: any TerminalCommandExecuting

    init(
        workingDirectory: String = FileManager.default.currentDirectoryPath,
        executor: any TerminalCommandExecuting = ShellCommandExecutor()
    ) {
        self.workingDirectory = workingDirectory
        self.executor = executor
    }

    var visibleLines: [TerminalOutputLine] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return lines }
        return lines.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    func submit() {
        let value = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !isRunning else { return }

        command = ""
        isRunning = true
        lines.append(.init(text: value, kind: .command))

        Task {
            let result = await executor.execute(
                command: value,
                workingDirectory: workingDirectory
            )
            apply(result)
        }
    }

    func clear() {
        lines.removeAll()
    }

    private func apply(_ result: TerminalCommandResult) {
        if !result.output.isEmpty {
            lines.append(.init(text: result.output, kind: result.exitCode == 0 ? .output : .error))
        }
        if !result.error.isEmpty {
            lines.append(.init(text: result.error, kind: .error))
        }
        if result.exitCode == 0 {
            lines.append(.init(text: "命令完成", kind: .success))
        }
        isRunning = false
    }
}
