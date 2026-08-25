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
            } else {
                ContentUnavailableView(
                    "项目还没有可用会话",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("选择项目联系人并发送第一条消息后，会话会显示在这里。")
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
