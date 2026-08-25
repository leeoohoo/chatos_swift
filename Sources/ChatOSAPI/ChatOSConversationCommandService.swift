import ChatOSCore
import Foundation

public actor ChatOSConversationCommandService: ConversationCommandServicing {
    private let client: ChatOSAPIClient

    public init(client: ChatOSAPIClient) {
        self.client = client
    }

    public func sendNewTurn(
        _ command: ConversationSendCommand
    ) async throws -> ConversationCommandAck {
        async let settings: RuntimeSettingsDTO = client.request(
            "/conversations/\(command.sessionID.urlPathEncoded)/runtime-settings"
        )
        async let modelConfigs: [ModelConfigDTO] = client.request("/ai-model-configs")

        let (runtime, configs) = try await (settings, modelConfigs)
        let model = try resolveModel(runtime: runtime, configs: configs)
        let request = ChatCommandRequestDTO(
            conversationID: command.sessionID,
            content: command.content,
            reasoningEnabled: command.reasoningEnabled ?? runtime.reasoningEnabled,
            planMode: command.planModeEnabled ?? runtime.planModeEnabled,
            turnID: command.turnID,
            remoteConnectionID: runtime.remoteConnectionID,
            workspaceRoot: runtime.workspaceRoot,
            modelConfigID: model.id,
            aiModelConfig: .init(
                temperature: model.temperature ?? 0.7,
                modelName: runtime.selectedModelName?.trimmedNonEmptyValue ?? model.modelName,
                thinkingLevel: runtime.selectedThinkingLevel?.trimmedNonEmptyValue
                    ?? model.thinkingLevel
            )
        )
        let response: ChatCommandResponseDTO = try await client.request(
            "/agent/chat/send",
            method: "POST",
            body: try JSONEncoder().encode(request)
        )
        guard response.accepted != false else {
            throw ChatOSAPIError.server(statusCode: 409, message: "聊天命令未被接受")
        }
        return response.ack(fallbackTurnID: command.turnID)
    }

    public func sendGuidance(
        _ command: ConversationSendCommand
    ) async throws -> ConversationCommandAck {
        let request = GuidanceRequestDTO(
            conversationID: command.sessionID,
            turnID: command.turnID,
            content: command.content
        )
        let response: ChatCommandResponseDTO = try await client.request(
            "/agent/chat/guidance",
            method: "POST",
            body: try JSONEncoder().encode(request)
        )
        guard response.accepted != false else {
            throw ChatOSAPIError.server(statusCode: 409, message: "追加指令未被接受")
        }
        return response.ack(fallbackTurnID: command.turnID)
    }

    private func resolveModel(
        runtime: RuntimeSettingsDTO,
        configs: [ModelConfigDTO]
    ) throws -> ModelConfigDTO {
        let enabled = configs.filter {
            $0.enabled != false && $0.modelName.trimmedNonEmptyValue != nil
        }
        if let selectedID = runtime.selectedModelID?.trimmedNonEmptyValue,
           let selected = enabled.first(where: { $0.id == selectedID }) {
            return selected
        }
        guard let fallback = enabled.first else {
            throw ChatOSAPIError.missingModelConfiguration
        }
        return fallback
    }
}
