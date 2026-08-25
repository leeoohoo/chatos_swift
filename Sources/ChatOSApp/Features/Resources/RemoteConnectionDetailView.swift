import ChatOSCore
import SwiftUI

struct RemoteConnectionDetailView: View {
    @EnvironmentObject private var model: AppModel
    let connectionID: String

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var isTesting = false
    @State private var notice: String?
    @State private var errorMessage: String?
    @State private var verificationPrompt: String?
    @State private var verificationCode = ""

    var body: some View {
        Group {
            if let connection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        connectionHeader(connection)
                        connectionDetails(connection)
                        if let notice {
                            Label(notice, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        ContentUnavailableView(
                            "远端 Terminal 与文件",
                            systemImage: "terminal",
                            description: Text("连接管理已经接通；下一项将实现 Terminal 会话和 SFTP 工作区。")
                        )
                        .frame(maxWidth: .infinity, minHeight: 260)
                        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(22)
                }
                .navigationTitle(connection.name)
                .toolbar { toolbar(connection) }
            } else {
                ContentUnavailableView(
                    "远端连接不存在",
                    systemImage: "network.slash",
                    description: Text("它可能已经被删除，请刷新资源列表。")
                )
            }
        }
        .workspaceFill()
        .sheet(isPresented: $showingEditor) {
            RemoteConnectionEditorSheetHost(
                editingConnection: connection,
                connections: model.remoteConnections,
                connectorStatus: model.localConnectorControl.status,
                service: model.remoteConnectionService,
                onSaved: model.registerRemoteConnection
            )
        }
        .sheet(isPresented: verificationPresented) { verificationSheet }
        .confirmationDialog(
            "删除远端连接？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                Task {
                    do { try await model.deleteRemoteConnection(id: connectionID) }
                    catch { errorMessage = error.localizedDescription }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会删除 ChatOS 保存的连接配置，不会修改远端服务器。")
        }
    }

    private var connection: RemoteConnection? { model.remoteConnection(id: connectionID) }

    private func connectionHeader(_ connection: RemoteConnection) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "network.badge.shield.half.filled")
                .appFont(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.name).appFont(.title2.weight(.semibold))
                Text("\(connection.username)@\(connection.host):\(connection.port)")
                    .appFont(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusCapsule(title: isTesting ? "测试中" : "已保存", color: isTesting ? .orange : .green)
        }
    }

    private func connectionDetails(_ connection: RemoteConnection) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 26, verticalSpacing: 12) {
            detailRow("认证方式", authenticationLabel(connection.authenticationType))
            detailRow("主机密钥", connection.hostKeyPolicy == .strict ? "严格校验" : "首次接受新密钥")
            detailRow("默认目录", connection.defaultRemotePath ?? "登录目录")
            detailRow("本机工作区", workspaceLabel(connection.localConnectorWorkspaceID))
            detailRow("跳板机", connection.jumpEnabled ? jumpLabel(connection) : "未启用")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(AppPalette.border, lineWidth: 1)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).appFont(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).appFont(.body).textSelection(.enabled)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(_ connection: RemoteConnection) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                Task { await testSavedConnection(code: nil) }
            } label: {
                Label("测试连接", systemImage: "bolt.horizontal.circle")
            }
            .disabled(isTesting)
            Button("编辑", systemImage: "pencil") { showingEditor = true }
            Menu {
                Button("删除连接", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func testSavedConnection(code: String?) async {
        isTesting = true
        notice = nil
        errorMessage = nil
        do {
            let result = try await model.remoteConnectionService.testSaved(
                id: connectionID,
                verificationCode: code
            )
            notice = result.message?.nonEmpty ?? "连接测试成功。"
            verificationPrompt = nil
            verificationCode = ""
        } catch let challenge as RemoteVerificationChallenge {
            verificationPrompt = challenge.prompt
            verificationCode = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isTesting = false
    }

    private var verificationPresented: Binding<Bool> {
        Binding(
            get: { verificationPrompt != nil },
            set: { if !$0 { verificationPrompt = nil } }
        )
    }

    private var verificationSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SSH 二次验证").appFont(.title3.weight(.semibold))
            Text(verificationPrompt ?? "请输入验证码。")
                .appFont(.body).foregroundStyle(.secondary)
            TextField("验证码", text: $verificationCode).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { verificationPrompt = nil }
                Button("验证") {
                    let code = verificationCode
                    Task { await testSavedConnection(code: code) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 440)
    }

    private func authenticationLabel(_ type: RemoteAuthenticationType) -> String {
        switch type {
        case .privateKey: "私钥"
        case .privateKeyCertificate: "私钥 + 证书"
        case .password: "密码"
        }
    }

    private func workspaceLabel(_ id: String) -> String {
        model.localConnectorControl.status?.workspaces.first(where: { $0.id == id })?.alias
            ?? "工作区不可用"
    }

    private func jumpLabel(_ connection: RemoteConnection) -> String {
        if let jumpID = connection.jumpConnectionID,
           let jump = model.remoteConnection(id: jumpID) {
            return "\(jump.name)（\(jump.username)@\(jump.host)）"
        }
        if let host = connection.jumpHost { return host }
        return "已启用"
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
