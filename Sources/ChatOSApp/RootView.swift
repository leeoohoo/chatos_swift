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

                GlobalApprovalOverlayHost(viewModel: model.localConnectorControl)
                    .padding(18)
                    .zIndex(30)

                VisualSessionOverlayHost(
                    store: model.visualSessionStore,
                    currentConversationID: model.currentConversationID
                )
                .padding(18)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: model.localConnectorControl.pendingApprovals.isEmpty
                        ? .topTrailing
                        : .bottomTrailing
                )
                .zIndex(20)
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
                    .id(projectID)
            case let .contact(contactID):
                ContactConversationView(contactID: contactID)
            case .localConnector:
                LocalConnectorControlCenterView(viewModel: model.localConnectorControl)
            case .terminal:
                TerminalWorkspaceView()
            case let .remote(remoteID):
                RemoteConnectionDetailView(connectionID: remoteID)
            case nil:
                ContentUnavailableView(
                    model.localized("选择一个资源开始", english: "Select a resource to begin"),
                    systemImage: "sidebar.left",
                    description: Text(model.localized(
                        "联系人用于持续对话，项目包含目录、用户消息、Plan 和运行设置。",
                        english: "Contacts provide ongoing conversations. Projects include files, messages, plans, and runtime settings."
                    ))
                )
            }
        }
        .workspaceFill()
    }
}
