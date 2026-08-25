import ChatOSCore
import SwiftUI

struct LocalConnectorPluginsView: View {
    @ObservedObject var viewModel: LocalConnectorControlCenterViewModel
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("搜索 Plugin、Skill 或发布者", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Text("\(filteredPlugins.count) 项")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.bar)

            if viewModel.plugins.isEmpty && viewModel.isLoading {
                ProgressView("正在同步 Plugin Marketplace…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPlugins.isEmpty {
                ContentUnavailableView(
                    "没有匹配的 Plugin",
                    systemImage: "puzzlepiece.extension",
                    description: Text(searchText.isEmpty ? "本机和云端目录当前为空。" : "尝试更换搜索词。")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                        ForEach(filteredPlugins) { plugin in
                            pluginCard(plugin)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private var filteredPlugins: [LocalConnectorPlugin] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.plugins }
        return viewModel.plugins.filter {
            [$0.displayName, $0.description, $0.publisher, $0.category]
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    private func pluginCard(_ plugin: LocalConnectorPlugin) -> some View {
        let isOperating = viewModel.pluginOperationIDs.contains(plugin.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tint)
                    .frame(width: 38, height: 38)
                    .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(plugin.displayName)
                        .font(.headline)
                    Text("\(plugin.publisher) · \(plugin.latestVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isOperating {
                    ProgressView()
                        .controlSize(.small)
                }
                if plugin.installed {
                    Toggle(
                        "启用",
                        isOn: Binding(
                            get: { plugin.enabled },
                            set: { viewModel.setPluginEnabled(id: plugin.id, enabled: $0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
            Text(plugin.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
            HStack {
                Text(plugin.category)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                if plugin.updateAvailable {
                    Label("有更新", systemImage: "arrow.down.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                Spacer()
                if plugin.installed {
                    if plugin.updateAvailable {
                        Button("更新") { viewModel.installPlugin(id: plugin.id) }
                            .buttonStyle(.borderedProminent)
                    }
                    Button("卸载", role: .destructive) { viewModel.uninstallPlugin(id: plugin.id) }
                } else {
                    Button("安装") { viewModel.installPlugin(id: plugin.id) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!plugin.installAvailable)
                }
            }
            .disabled(isOperating)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.separator.opacity(0.65)) }
    }
}
