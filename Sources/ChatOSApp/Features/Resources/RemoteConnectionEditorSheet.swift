import ChatOSCore
import SwiftUI

struct RemoteConnectionEditorSheetHost: View {
    @StateObject private var viewModel: RemoteConnectionEditorViewModel
    let onSaved: (RemoteConnection) -> Void

    init(
        editingConnection: RemoteConnection?,
        connections: [RemoteConnection],
        connectorStatus: LocalConnectorStatus?,
        service: any RemoteConnectionServicing,
        onSaved: @escaping (RemoteConnection) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: RemoteConnectionEditorViewModel(
            editingConnection: editingConnection,
            connections: connections,
            connectorStatus: connectorStatus,
            service: service
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        RemoteConnectionEditorSheet(viewModel: viewModel, onSaved: onSaved)
    }
}

private struct RemoteConnectionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RemoteConnectionEditorViewModel
    let onSaved: (RemoteConnection) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                RemoteConnectionBasicsSection(viewModel: viewModel)
                RemoteConnectionExecutionSection(viewModel: viewModel)
                RemoteConnectionAuthenticationSection(viewModel: viewModel)
                RemoteConnectionJumpSection(viewModel: viewModel)
                feedback
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            Divider()
            footer
        }
        .frame(minWidth: 700, idealWidth: 760, minHeight: 680, idealHeight: 760)
        .sheet(isPresented: verificationPresented) {
            verificationSheet
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "network.badge.shield.half.filled")
                .appFont(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title).appFont(.title3.weight(.semibold))
                Text("连接由本机网关执行，凭据不会展示在界面中。")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
    }

    @ViewBuilder
    private var feedback: some View {
        if let successMessage = viewModel.successMessage {
            Section {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        if let errorMessage = viewModel.errorMessage {
            Section {
                Label {
                    Text(errorMessage).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.orange)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                if viewModel.isTesting {
                    ProgressView().controlSize(.small)
                } else {
                    Label("测试连接", systemImage: "bolt.horizontal.circle")
                }
            }
            .disabled(viewModel.isBusy)

            Spacer()
            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isBusy)
            Button(viewModel.editingConnection == nil ? "创建" : "保存") {
                Task {
                    if let connection = await viewModel.save() {
                        onSaved(connection)
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.isBusy)
        }
        .padding(14)
    }

    private var verificationPresented: Binding<Bool> {
        Binding(
            get: { viewModel.verificationPrompt != nil },
            set: { if !$0 { viewModel.verificationPrompt = nil } }
        )
    }

    private var verificationSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SSH 二次验证").appFont(.title3.weight(.semibold))
            Text(viewModel.verificationPrompt ?? "请输入服务器要求的验证码。")
                .appFont(.body)
                .foregroundStyle(.secondary)
            TextField("验证码", text: $viewModel.verificationCode)
                .textFieldStyle(.roundedBorder)
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).appFont(.caption).foregroundStyle(.orange)
            }
            HStack {
                Spacer()
                Button("取消") { viewModel.verificationPrompt = nil }
                Button("验证") { Task { await viewModel.submitVerification() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isTesting)
            }
        }
        .padding(22)
        .frame(width: 440)
    }
}
