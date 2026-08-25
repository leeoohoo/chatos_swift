import SwiftUI

struct ConversationHistoryStatusView: View {
    @ObservedObject var conversation: ConversationSessionViewModel

    var body: some View {
        if conversation.isRefreshing {
            Label("正在同步最新消息…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.05))
        } else if let error = conversation.historyError {
            HStack(spacing: 8) {
                Label("历史同步失败", systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.medium))
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("重试", action: conversation.refreshLatest)
                    .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 7)
            .background(Color.orange.opacity(0.08))
        }
    }
}
