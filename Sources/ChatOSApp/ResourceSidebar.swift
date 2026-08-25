import SwiftUI

struct ResourceSidebar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selection) {
            Section("联系人") {
                if model.isWorkspaceLoading && model.contacts.isEmpty {
                    ProgressView("正在加载联系人…")
                        .controlSize(.small)
                }
                ForEach(model.contacts) { contact in
                    resourceRow(
                        title: contact.title,
                        subtitle: contact.subtitle,
                        systemImage: "person.crop.circle.fill",
                        tint: .secondary
                    )
                    .tag(SidebarSelection.contact(contact.id))
                }
            }

            Section("项目") {
                if model.isWorkspaceLoading && model.projects.isEmpty {
                    ProgressView("正在加载项目…")
                        .controlSize(.small)
                }
                ForEach(model.projects) { project in
                    resourceRow(
                        title: project.title,
                        subtitle: project.subtitle,
                        systemImage: "folder",
                        tint: .accentColor
                    )
                    .tag(SidebarSelection.project(project.id))
                }
            }

            Section("本机") {
                ForEach(model.terminals) { terminal in
                    resourceRow(
                        title: terminal.title,
                        subtitle: terminal.subtitle,
                        systemImage: "terminal",
                        tint: AppPalette.terminalGreen
                    )
                    .tag(SidebarSelection.terminal(terminal.id))
                }
            }

            Section("远端") {
                Label("还没有远端连接", systemImage: "network")
                    .foregroundStyle(.secondary)
            }

            if let workspaceError = model.workspaceError {
                Section {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("资源同步失败", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(workspaceError)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Button("重试", action: model.refreshWorkspace)
                            .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ChatOS")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("刷新资源", systemImage: "arrow.clockwise", action: model.refreshWorkspace)
                    .labelStyle(.iconOnly)
                    .disabled(model.isWorkspaceLoading)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("新建联系人", systemImage: "person.badge.plus") {}
                    Button("新建项目", systemImage: "folder.badge.plus") {}
                    Button("新建终端", systemImage: "terminal") {}
                    Divider()
                    Button("新建远端连接", systemImage: "network.badge.shield.half.filled") {}
                } label: {
                    Image(systemName: "plus")
                }
                .help("新建资源")
            }
        }
    }

    private func resourceRow(
        title: String,
        subtitle: String?,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, subtitle == nil ? 2 : 3)
    }
}
