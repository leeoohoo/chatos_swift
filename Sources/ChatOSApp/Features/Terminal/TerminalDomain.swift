import Foundation

struct TerminalOutputLine: Identifiable, Sendable {
    enum Kind: Sendable, Equatable {
        case command
        case output
        case error
        case success
        case system
    }

    let id = UUID()
    let text: String
    let kind: Kind
}

struct TerminalCommandResult: Sendable {
    let output: String
    let error: String
    let exitCode: Int32
}

protocol TerminalCommandExecuting: Sendable {
    func execute(command: String, workingDirectory: String) async -> TerminalCommandResult
}
