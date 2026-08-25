import SwiftUI

struct LoginView: View {
    @ObservedObject var authentication: AuthenticationViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case password
    }

    var body: some View {
        HStack(spacing: 0) {
            introduction
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.accentColor.opacity(0.055))

            loginForm
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .onAppear { focusedField = .username }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 30) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppPalette.ai)
                .frame(width: 74, height: 74)
                .background(AppPalette.ai.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 12) {
                Text("把长期项目，变成\n可以持续推进的协作。")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .lineSpacing(5)
                Text("工作区、聊天、任务过程和本机能力全部原生呈现。")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 22) {
                feature("联系人和项目保持上下文", "bubble.left.and.bubble.right")
                feature("任务流程和阻塞状态可追踪", "point.3.connected.trianglepath.dotted")
                feature("敏感能力留在本机安全边界", "lock.shield")
            }
        }
        .frame(maxWidth: 510, alignment: .leading)
        .padding(70)
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 7) {
                Text("登录")
                    .font(.system(size: 29, weight: .bold))
                Text("使用 ChatOS 平台账号继续")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 18) {
                fieldLabel("账号")
                TextField("name@example.com", text: $authentication.username)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }

                fieldLabel("密码")
                SecureField("密码", text: $authentication.password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .password)
                    .onSubmit(authentication.login)
            }

            if let errorMessage = authentication.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: authentication.login) {
                HStack {
                    Spacer()
                    if authentication.phase == .authenticating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("登录").fontWeight(.semibold)
                    }
                    Spacer()
                }
                .frame(height: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!authentication.canLogin)

            Label("APISIX 网关 · 127.0.0.1:9080", systemImage: "network")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.quaternary, in: Capsule())
        }
        .frame(width: 410)
        .padding(70)
    }

    private func feature(_ title: String, _ systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.primary)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.bottom, -11)
    }
}
