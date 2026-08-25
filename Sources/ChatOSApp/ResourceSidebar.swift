import SwiftUI

struct ResourceSidebar: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.interfaceFontScale) private var interfaceFontScale

    var body: some View {
        List(selection: $model.selection) {
            Section {
                if model.isWorkspaceLoading && model.contacts.isEmpty {
                    loadingRow("正在加载联系人…")
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
            } header: {
                sectionHeader("联系人")
            }

            Section {
                if model.isWorkspaceLoading && model.projects.isEmpty {
                    loadingRow("正在加载项目…")
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
            } header: {
                sectionHeader("项目")
            }

            Section {
                ForEach(model.terminals) { terminal in
                    resourceRow(
                        title: terminal.title,
                        subtitle: terminal.subtitle,
                        systemImage: "terminal",
                        tint: AppPalette.terminalGreen
                    )
                    .tag(SidebarSelection.terminal(terminal.id))
                }
            } header: {
                sectionHeader("本机")
            }

            Section {
                HStack(spacing: 10) {
                    Image(systemName: "network")
                        .frame(width: 18)
                    Text("还没有远端连接")
                        .appFont(.body)
                }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, rowVerticalPadding)
            } header: {
                sectionHeader("远端")
            }

            if let workspaceError = model.workspaceError {
                Section {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("资源同步失败", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(workspaceError)
                            .appFont(.caption2)
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
                    .appFont(.body.weight(.medium))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, rowVerticalPadding)
    }

    private var rowVerticalPadding: CGFloat {
        3 + max(0, interfaceFontScale - 1) * 5
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .appFont(.caption.weight(.semibold))
    }

    private func loadingRow(_ title: String) -> some View {
        HStack(spacing: 9) {
            ProgressView()
                .controlSize(.small)
            Text(title)
                .appFont(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, rowVerticalPadding)
    }
}
