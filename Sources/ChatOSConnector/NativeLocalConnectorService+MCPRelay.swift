import ChatOSCore
import Foundation

extension NativeLocalConnectorService {
    func handleMCPRelayMessage(
        _ data: Data,
        socket: URLSessionWebSocketTask
    ) async {
        let decoded = try? JSONDecoder().decode(NativeRelayRequest.self, from: data)
        let requestID = decoded?.requestID ?? ""
        do {
            guard let request = decoded else { throw NativeMCPRelayError.invalidRequest }
            let response = try await processMCPRelay(request)
            try await sendRelayResponse(response, socket: socket)
        } catch {
            let response = NativeRelayResponse(
                type: "mcp",
                requestID: requestID,
                status: 400,
                body: Self.rpcError(id: nil, code: -32603, message: error.localizedDescription)
            )
            try? await sendRelayResponse(response, socket: socket)
        }
    }

    private func processMCPRelay(_ request: NativeRelayRequest) async throws -> NativeRelayResponse {
        guard request.type == "mcp",
              let ownerUserID = state.user?.id,
              let deviceID = state.deviceID,
              let workspace = state.workspaces.first(where: { $0.id == request.workspaceID }) else {
            throw NativeMCPRelayError.invalidContext
        }
        let token = try requireAccessToken()
        let runtime = try await gateway.managedRuntimeConfig(token: token)
        try NativeRelayVerifier().verify(
            request,
            trust: runtime.remoteControlTrust,
            ownerUserID: ownerUserID,
            deviceID: deviceID,
            seenNonces: &seenRelayNonces
        )

        let call = try NativeMCPToolCall(request.body)
        guard call.method == "tools/call" else {
            return .init(
                type: "mcp",
                requestID: request.requestID,
                status: 200,
                body: Self.rpcError(id: call.id, code: -32601, message: "暂不支持该 MCP 方法")
            )
        }
        guard call.name == "execute_command" else {
            return .init(
                type: "mcp",
                requestID: request.requestID,
                status: 200,
                body: Self.rpcError(id: call.id, code: -32601, message: "暂不支持 MCP 工具：\(call.name)")
            )
        }

        let command = call.arguments.string("common")
            ?? call.arguments.string("command")
            ?? ""
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeMCPRelayError.emptyCommand
        }
        let workspaceRoot = URL(fileURLWithPath: workspace.absoluteRoot)
        let projectRoot = try resolveDirectory(
            request.header("x-local-connector-cwd") ?? ".",
            relativeTo: workspaceRoot,
            workspace: workspace
        )
        let cwd = try resolveDirectory(
            call.arguments.string("path") ?? ".",
            relativeTo: projectRoot,
            workspace: workspace
        )
        let shellArguments = ["-lc", command]
        let risk = NativeApprovalRiskEvaluator.evaluate(command: "/bin/zsh", arguments: shellArguments)
        let source = isHarnessImport(command) ? "project-harness-import" : "local-mcp"
        let decision: NativeApprovalDecision
        if source == "project-harness-import" {
            decision = .approve(
                reason: "用户创建本机项目时，由平台签名的 Harness 导入流程发起。",
                rememberAllow: false
            )
        } else {
            decision = await approvalDecision(
                requestID: request.requestID,
                command: "/bin/zsh",
                arguments: shellArguments,
                cwd: cwd,
                projectRoot: projectRoot,
                source: source,
                risk: risk
            )
        }

        switch decision {
        case let .deny(reason), let .askUser(reason):
            appendApprovalHistory(
                command: "/bin/zsh",
                arguments: shellArguments,
                cwd: cwd.path,
                source: source,
                decision: "denied",
                risk: risk,
                reason: reason
            )
            return Self.mcpCommandResponse(
                requestID: request.requestID,
                rpcID: call.id,
                command: command,
                cwd: cwd.path,
                result: nil,
                error: reason
            )
        case let .approve(reason, _):
            appendApprovalHistory(
                command: "/bin/zsh",
                arguments: shellArguments,
                cwd: cwd.path,
                source: source,
                decision: "approved",
                risk: risk,
                reason: reason
            )
        }

        let result = try await Task.detached {
            try NativeTerminalExecutor.execute(
                command: "/bin/zsh",
                args: shellArguments,
                cwd: cwd.path,
                workspace: workspace
            )
        }.value
        appendCommandHistory(
            result: result,
            display: command,
            workspace: workspace,
            source: source
        )
        return Self.mcpCommandResponse(
            requestID: request.requestID,
            rpcID: call.id,
            command: command,
            cwd: cwd.path,
            result: result,
            error: result.error
        )
    }

    private func isHarnessImport(_ command: String) -> Bool {
        command.contains("Import local project into ChatOS Harness")
            && command.contains("git push --force origin HEAD:refs/heads/")
            && command.contains("chatos-harness-import-")
    }

    private nonisolated static func mcpCommandResponse(
        requestID: String,
        rpcID: NativeJSONValue,
        command: String,
        cwd: String,
        result: LocalConnectorTerminalResult?,
        error: String?
    ) -> NativeRelayResponse {
        let structured = NativeJSONValue.object([
            "command": .string(command),
            "common": .string(command),
            "path": .string(cwd),
            "success": .bool(result?.success ?? false),
            "exit_code": result?.exitCode.map { .number(Double($0)) } ?? .null,
            "timed_out": .bool(result?.timedOut ?? false),
            "stdout": .string(result?.stdout ?? ""),
            "stderr": .string(result?.stderr ?? ""),
            "error": error.map(NativeJSONValue.string) ?? .null,
        ])
        let toolResult = NativeJSONValue.object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(structured.canonicalJSONString),
                ]),
            ]),
            "_structured_result": structured,
        ])
        return .init(
            type: "mcp",
            requestID: requestID,
            status: 200,
            body: .object([
                "jsonrpc": .string("2.0"),
                "id": rpcID,
                "result": toolResult,
            ])
        )
    }

    private nonisolated static func rpcError(
        id: NativeJSONValue?,
        code: Int,
        message: String
    ) -> NativeJSONValue {
        .object([
            "jsonrpc": .string("2.0"),
            "id": id ?? .null,
            "error": .object([
                "code": .number(Double(code)),
                "message": .string(message),
            ]),
        ])
    }
}

private struct NativeMCPToolCall {
    var id: NativeJSONValue
    var method: String
    var name: String
    var arguments: [String: NativeJSONValue]

    init(_ value: NativeJSONValue) throws {
        guard case let .object(root) = value,
              case let .string(method)? = root["method"],
              case let .object(params)? = root["params"],
              case let .string(name)? = params["name"] else {
            throw NativeMCPRelayError.invalidRequest
        }
        self.id = root["id"] ?? .null
        self.method = method
        self.name = name
        if case let .object(arguments)? = params["arguments"] {
            self.arguments = arguments
        } else {
            self.arguments = [:]
        }
    }
}

private extension Dictionary where Key == String, Value == NativeJSONValue {
    func string(_ key: String) -> String? {
        guard case let .string(value)? = self[key] else { return nil }
        return value
    }
}

private enum NativeMCPRelayError: LocalizedError {
    case invalidRequest, invalidContext, emptyCommand

    var errorDescription: String? {
        switch self {
        case .invalidRequest: "MCP Relay 请求格式无效"
        case .invalidContext: "MCP Relay 请求与当前设备或工作区不匹配"
        case .emptyCommand: "MCP execute_command 缺少命令"
        }
    }
}
