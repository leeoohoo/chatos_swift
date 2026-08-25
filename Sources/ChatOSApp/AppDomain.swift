enum SidebarSelection: Hashable {
    case contact(String)
    case project(String)
    case localConnector
    case terminal(String)
    case remote(String)
}

enum ProjectWorkspaceTab: String, CaseIterable, Identifiable {
    case directory = "项目目录"
    case messages = "用户消息"
    case plan = "Plan"
    case settings = "项目设置"

    var id: Self { self }
}

struct ResourceItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let conversationID: String?
    let contactName: String?
}

struct VisualSessionPresentation: Equatable {
    var ownerSessionID: String
    var title: String
    var targetApplication: String
    var isExpanded: Bool
}
