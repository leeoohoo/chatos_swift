import AppKit
import ChatOSCore
import SwiftUI

struct RemoteConnectionBasicsSection: View {
    @ObservedObject var viewModel: RemoteConnectionEditorViewModel

    var body: some View {
        Section("连接") {
            TextField("名称（可选）", text: $viewModel.name)
            HStack {
                TextField("主机，例如 server.example.com", text: $viewModel.host)
                TextField("端口", text: $viewModel.port)
                    .frame(width: 90)
            }
            TextField("用户名", text: $viewModel.username)
            Picker("主机密钥", selection: $viewModel.hostKeyPolicy) {
                Text("严格校验 known_hosts").tag(RemoteHostKeyPolicy.strict)
                Text("首次连接时接受新密钥").tag(RemoteHostKeyPolicy.acceptNew)
            }
        }
    }
}

struct RemoteConnectionExecutionSection: View {
    @ObservedObject var viewModel: RemoteConnectionEditorViewModel

    var body: some View {
        Section {
            Picker("执行工作区", selection: $viewModel.workspaceID) {
                if viewModel.workspaces.isEmpty {
                    Text("没有可用工作区").tag("")
                }
                ForEach(viewModel.workspaces) { workspace in
                    Text("\(workspace.alias) — \(workspace.absoluteRoot)").tag(workspace.id)
                }
            }
        } header: {
            Text("本机执行目标")
        } footer: {
            Text("SSH、Terminal 和 SFTP 会由这个本机网关工作区执行。")
        }
    }
}

struct RemoteConnectionAuthenticationSection: View {
    @ObservedObject var viewModel: RemoteConnectionEditorViewModel

    var body: some View {
        Section("认证") {
            Picker("认证方式", selection: $viewModel.authenticationType) {
                Text("私钥").tag(RemoteAuthenticationType.privateKey)
                Text("私钥 + 证书").tag(RemoteAuthenticationType.privateKeyCertificate)
                Text("密码").tag(RemoteAuthenticationType.password)
            }

            if viewModel.authenticationType == .password {
                SecureField(
                    viewModel.editingConnection?.hasPassword == true
                        ? "留空则继续使用已保存密码"
                        : "登录密码",
                    text: $viewModel.password
                )
            } else {
                filePathRow(
                    title: "私钥路径",
                    placeholder: viewModel.editingConnection?.hasPrivateKeyPath == true
                        ? "留空则继续使用已保存私钥"
                        : "/Users/you/.ssh/id_ed25519",
                    text: $viewModel.privateKeyPath
                )
                if viewModel.authenticationType == .privateKeyCertificate {
                    filePathRow(
                        title: "证书路径",
                        placeholder: viewModel.editingConnection?.hasCertificatePath == true
                            ? "留空则继续使用已保存证书"
                            : "/Users/you/.ssh/id_ed25519-cert.pub",
                        text: $viewModel.certificatePath
                    )
                }
            }
            TextField("默认远端目录，例如 /srv/app", text: $viewModel.defaultRemotePath)
        }
    }

    private func filePathRow(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack {
            TextField(placeholder, text: text)
            Button("选择…") {
                if let path = selectFile(title: title) { text.wrappedValue = path }
            }
        }
    }
}

struct RemoteConnectionJumpSection: View {
    @ObservedObject var viewModel: RemoteConnectionEditorViewModel

    var body: some View {
        Section {
            Toggle("通过跳板机连接", isOn: $viewModel.jumpEnabled)
            if viewModel.jumpEnabled {
                Picker("跳板机来源", selection: $viewModel.jumpMode) {
                    ForEach(RemoteJumpMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                .pickerStyle(.segmented)

                if viewModel.jumpMode == .existing {
                    Picker("已有连接", selection: $viewModel.jumpConnectionID) {
                        Text("请选择").tag("")
                        ForEach(viewModel.availableJumpConnections) { connection in
                            Text("\(connection.name) — \(connection.username)@\(connection.host):\(connection.port)")
                                .tag(connection.id)
                        }
                    }
                } else {
                    HStack {
                        TextField("跳板机地址", text: $viewModel.jumpHost)
                        TextField("端口", text: $viewModel.jumpPort).frame(width: 90)
                    }
                    TextField("跳板机用户名", text: $viewModel.jumpUsername)
                    jumpFileRow("跳板机私钥", text: $viewModel.jumpPrivateKeyPath)
                    jumpFileRow("跳板机证书（可选）", text: $viewModel.jumpCertificatePath)
                    SecureField("跳板机密码（可选）", text: $viewModel.jumpPassword)
                }
            }
        } header: {
            Text("跳板机")
        } footer: {
            if viewModel.jumpEnabled {
                Text("可以复用已有远端连接，或单独保存这条连接的跳板机凭据。")
            }
        }
    }

    private func jumpFileRow(_ title: String, text: Binding<String>) -> some View {
        HStack {
            TextField(title, text: text)
            Button("选择…") {
                if let path = selectFile(title: title) { text.wrappedValue = path }
            }
        }
    }
}

@MainActor
private func selectFile(title: String) -> String? {
    let panel = NSOpenPanel()
    panel.title = title
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.showsHiddenFiles = true
    return panel.runModal() == .OK ? panel.url?.path : nil
}
