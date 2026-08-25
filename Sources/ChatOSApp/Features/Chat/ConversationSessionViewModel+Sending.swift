import ChatOSCore
import Foundation

extension ConversationSessionViewModel {
    func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        guard let commandService else {
            historyError = "聊天发送服务尚未连接。"
            return
        }

        if let activeTurn = turns.last(where: { $0.status == .streaming }) {
            sendGuidance(text, turnID: activeTurn.id, using: commandService)
        } else {
            sendNewTurn(text, using: commandService)
        }
    }

    private func sendGuidance(
        _ text: String,
        turnID: String,
        using service: any ConversationCommandServicing
    ) {
        beginSending(text)
        Task {
            do {
                _ = try await service.sendGuidance(
                    ConversationSendCommand(sessionID: sessionID, turnID: turnID, content: text)
                )
                refreshLatest()
            } catch {
                restoreDraft(text, error: error)
            }
            isSending = false
        }
    }

    private func sendNewTurn(
        _ text: String,
        using service: any ConversationCommandServicing
    ) {
        let turn = makeOptimisticTurn(text)
        beginSending(text)
        selectedTurnID = turn.id

        Task {
            await historyStore.applyRealtime(
                RealtimeTurnEvent(
                    eventID: "optimistic-\(turn.id)",
                    eventSequence: turn.sequence,
                    turn: turn
                ),
                userIsReadingOlderContent: false
            )
            await refreshSnapshot()

            do {
                _ = try await service.sendNewTurn(
                    ConversationSendCommand(
                        sessionID: sessionID,
                        turnID: turn.id,
                        content: text,
                        reasoningEnabled: reasoningEnabled,
                        planModeEnabled: allowsPlanMode && planModeEnabled
                    )
                )
                refreshLatest()
            } catch {
                await historyStore.discardOptimisticTurn(sessionID: sessionID, turnID: turn.id)
                await refreshSnapshot()
                restoreDraft(text, error: error)
            }
            isSending = false
        }
    }

    private func beginSending(_ text: String) {
        draft = ""
        historyError = nil
        isSending = true
    }

    private func restoreDraft(_ text: String, error: Error) {
        if draft.isEmpty { draft = text }
        historyError = error.localizedDescription
    }

    private func makeOptimisticTurn(_ text: String) -> ConversationTurn {
        let now = Date()
        return ConversationTurn(
            id: "turn_\(UUID().uuidString.lowercased())",
            sessionID: sessionID,
            sequence: (turns.map(\.sequence).max() ?? 0) + 1,
            revision: 0,
            userMessage: ChatMessage(
                id: "optimistic_\(UUID().uuidString.lowercased())",
                role: .user,
                text: text,
                createdAt: now
            ),
            status: .streaming,
            startedAt: now
        )
    }
}
