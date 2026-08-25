import SwiftUI

struct ProjectMessagesView: View {
    @EnvironmentObject private var model: AppModel
    let projectID: String

    var body: some View {
        let resource = model.projects.first(where: { $0.id == projectID })
        let projectName = resource?.title ?? projectID
        let contactName = resource?.contactName ?? "项目联系人"

        Group {
            if let conversation = model.projectConversation {
                ConversationTimelineView(
                    conversation: conversation,
                    title: "\(projectName) · \(contactName)",
                    showsTaskState: true
                )
                .frame(minWidth: 620)
            } else if model.isPreparingProjectConversation(projectID: projectID) {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在连接“叽咕狸”…")
                        .appFont(.headline)
                    Text("正在为项目准备首次会话，完成后即可直接发送消息。")
                        .appFont(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let error = model.projectConversationPreparationError(projectID: projectID) {
                ContentUnavailableView {
                    Label("会话准备失败", systemImage: "exclamationmark.bubble")
                } description: {
                    Text(error)
                } actions: {
                    Button("重试") {
                        model.retryProjectConversationPreparation(projectID: projectID)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView(
                    "项目还没有可用会话",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("正在等待默认联系人“叽咕狸”可用。")
                )
            }
        }
        .workspaceFill()
    }
}

struct ContactConversationView: View {
    @EnvironmentObject private var model: AppModel
    let contactID: String

    var body: some View {
        let contactName = model.contacts.first(where: { $0.id == contactID })?.title ?? "联系人"

        Group {
            if let conversation = model.contactConversation {
                ConversationTimelineView(
                    conversation: conversation,
                    title: contactName,
                    showsTaskState: false
                )
            } else {
                ContentUnavailableView(
                    "还没有公开会话",
                    systemImage: "bubble.left",
                    description: Text("发送第一条消息后，会话会显示在这里。")
                )
            }
        }
        .workspaceFill()
        .navigationTitle(contactName)
    }
}
