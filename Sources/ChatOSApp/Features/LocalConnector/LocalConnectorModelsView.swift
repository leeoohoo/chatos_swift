import ChatOSCore
import SwiftUI

struct LocalConnectorModelsView: View {
    @ObservedObject var viewModel: LocalConnectorControlCenterViewModel
    @State private var settingsDraft = LocalConnectorModelSettings(
        modelRequestMaxRetries: 5,
        commandApprovalModelConfigID: nil,
        commandApprovalThinkingLevel: nil
    )
    @State private var taskDrafts: [String: LocalConnectorTaskModelDraft] = [:]
    @State private var showingProviderManager = false
    @State private var validationMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                actionBar
                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                if let catalog = viewModel.modelCatalog {
                    LocalConnectorModelDefaultsSection(
                        models: catalog.items,
                        settings: $settingsDraft
                    )
                    retrySection
                    LocalConnectorTaskModelsSection(
                        models: catalog.items,
                        drafts: $taskDrafts
                    )
                } else {
                    ProgressView("正在读取完整模型配置…")
                        .frame(maxWidth: .infinity, minHeight: 260)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingProviderManager) {
            LocalConnectorProviderManagerSheet(viewModel: viewModel)
        }
        .onAppear { synchronizeDrafts(with: viewModel.modelCatalog) }
        .onChange(of: viewModel.modelCatalog) { _, catalog in
            synchronizeDrafts(with: catalog)
        }
    }

    private var actionBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("统一模型配置")
                    .font(.title3.weight(.semibold))
                Text("供应商与云端默认模型保存在 ChatOS；本机审批模型只保存在这台 Mac。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("管理供应商", systemImage: "server.rack") {
                showingProviderManager = true
            }
            Button("同步", systemImage: "arrow.triangle.2.circlepath") {
                viewModel.loadModels(refresh: true)
            }
            Button("保存全部", systemImage: "checkmark") { save() }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isPerformingAction || viewModel.modelCatalog == nil)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.separator.opacity(0.65)) }
    }

    private var retrySection: some View {
        LocalConnectorCard(
            "请求容错",
            subtitle: "网络波动、限流或上游暂时不可用时的最大重试次数。",
            systemImage: "arrow.clockwise.circle"
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("模型请求最大重试次数").font(.headline)
                    Text("允许范围 0–10，默认 5。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Stepper(
                    value: Binding(
                        get: { settingsDraft.modelRequestMaxRetries ?? 5 },
                        set: { settingsDraft.modelRequestMaxRetries = min(10, max(0, $0)) }
                    ),
                    in: 0...10
                ) {
                    Text("\(settingsDraft.modelRequestMaxRetries ?? 5) 次")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                .fixedSize()
            }
        }
    }

    private func synchronizeDrafts(with catalog: LocalConnectorModelCatalog?) {
        guard let catalog else { return }
        settingsDraft = catalog.settings
        taskDrafts = Dictionary(uniqueKeysWithValues: catalog.items.map {
            ($0.id, LocalConnectorTaskModelDraft(model: $0))
        })
        validationMessage = nil
    }

    private func save() {
        guard let catalog = viewModel.modelCatalog else { return }
        do {
            let updates = try Dictionary(uniqueKeysWithValues: catalog.items.map { model in
                let draft = taskDrafts[model.id] ?? .init(model: model)
                return (model.id, try draft.validatedUpdate(modelName: model.name))
            })
            var nextSettings = settingsDraft
            let enabledIDs = Set(updates.compactMap { $0.value.enabled ? $0.key : nil })
            clearDisabledSelection(\.memorySummaryModelConfigID, thinking: \.memorySummaryThinkingLevel, in: &nextSettings, enabledIDs: enabledIDs)
            clearDisabledSelection(\.projectManagementAgentModelConfigID, thinking: \.projectManagementAgentThinkingLevel, in: &nextSettings, enabledIDs: enabledIDs)
            clearDisabledSelection(\.commandApprovalModelConfigID, thinking: \.commandApprovalThinkingLevel, in: &nextSettings, enabledIDs: enabledIDs)
            validationMessage = nil
            viewModel.saveModelConfiguration(settings: nextSettings, updates: updates)
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func clearDisabledSelection(
        _ modelKeyPath: WritableKeyPath<LocalConnectorModelSettings, String?>,
        thinking thinkingKeyPath: WritableKeyPath<LocalConnectorModelSettings, String?>,
        in settings: inout LocalConnectorModelSettings,
        enabledIDs: Set<String>
    ) {
        guard let id = settings[keyPath: modelKeyPath], !enabledIDs.contains(id) else { return }
        settings[keyPath: modelKeyPath] = nil
        settings[keyPath: thinkingKeyPath] = nil
    }
}
