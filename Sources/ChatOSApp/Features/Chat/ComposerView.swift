import SwiftUI

struct ComposerView: View {
    @ObservedObject var conversation: ConversationSessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            controls
            input
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13).stroke(.separator, lineWidth: 1)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Menu("my / gpt-5.6-terra") {
                Button("my / gpt-5.6-terra") {}
                Button("my / gpt-5.6-luna") {}
            }
            Button("附件", systemImage: "paperclip") {}
                .labelStyle(.iconOnly)
            Menu("外挂程式") {
                Toggle("Open Computer Use", isOn: .constant(true))
            }
            if conversation.allowsPlanMode {
                Button("规划 \(conversation.planModeEnabled ? "开" : "关")") {
                    conversation.setPlanModeEnabled(!conversation.planModeEnabled)
                }
                .buttonStyle(.borderedProminent)
                .tint(conversation.planModeEnabled ? AppPalette.ai : .secondary.opacity(0.3))
                .help(
                    conversation.planModeEnabled
                        ? "开启后，AI 会先通过 Task Runner 生成待确认的任务图。"
                        : "关闭后，AI 可直接创建并执行任务。"
                )
                .disabled(conversation.isUpdatingRuntimeSettings)
            }
            Button("推理 \(conversation.reasoningEnabled ? "开" : "关")") {
                conversation.setReasoningEnabled(!conversation.reasoningEnabled)
            }
            .buttonStyle(.borderedProminent)
            .tint(conversation.reasoningEnabled ? AppPalette.ai : .secondary.opacity(0.3))
            .disabled(conversation.isUpdatingRuntimeSettings)
            Spacer()
        }
        .controlSize(.small)
    }

    private var input: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                "输入消息或在任务执行中发送引导…",
                text: $conversation.draft,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(1...6)
            .onSubmit(conversation.sendDraft)

            Button(action: conversation.sendDraft) {
                Group {
                    if conversation.isSending {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up").font(.headline)
                    }
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .disabled(
                conversation.isSending
                    || conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }
}
