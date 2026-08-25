import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        AuthenticationGateView(authentication: model.authentication) {
            workspace
        }
    }

    private var workspace: some View {
        NavigationSplitView {
            ResourceSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 244, max: 290)
        } detail: {
            ZStack(alignment: .topTrailing) {
                detail
                    .workspaceFill()

                if let visualSession = model.visualSession,
                   visualSession.ownerSessionID == model.currentConversationID {
                    VisualSessionOverlay(session: visualSession)
                        .padding(18)
                        .zIndex(20)
                }
            }
            .workspaceFill()
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.accentColor)
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch model.selection {
            case let .project(projectID):
                ProjectWorkspaceView(projectID: projectID)
            case let .contact(contactID):
                ContactConversationView(contactID: contactID)
            case .localConnector:
                LocalConnectorControlCenterView(viewModel: model.localConnectorControl)
            case .terminal:
                TerminalWorkspaceView()
            case let .remote(remoteID):
                ContentUnavailableView(
                    "远端连接",
                    systemImage: "network",
                    description: Text("远端资源 \(remoteID) 将在后续版本接入 SSH、Terminal 与 SFTP。")
                )
            case nil:
                ContentUnavailableView(
                    "选择一个资源开始",
                    systemImage: "sidebar.left",
                    description: Text("联系人用于持续对话，项目包含目录、用户消息、Plan 和运行设置。")
                )
            }
        }
        .workspaceFill()
    }
}
