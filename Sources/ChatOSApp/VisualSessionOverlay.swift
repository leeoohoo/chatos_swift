import SwiftUI

struct VisualSessionOverlay: View {
    @EnvironmentObject private var model: AppModel
    let session: VisualSessionPresentation

    var body: some View {
        if session.isExpanded {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.inset.filled.and.person.filled")
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(AppPalette.ai, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title)
                            .appFont(.caption.weight(.semibold))
                        HStack(spacing: 5) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text(session.targetApplication)
                                .appFont(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button(action: model.toggleVisualSession) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)

                Divider().opacity(0.25)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("收件箱")
                        Text("项目笔记")
                            .foregroundStyle(Color(red: 0.78, green: 0.75, blue: 1.0))
                        Text("每日记录")
                        Text("归档")
                    }
                    .appFont(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(width: 105)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.white.opacity(0.06))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("项目笔记")
                            .appFont(.subheadline.weight(.semibold))
                        Divider().opacity(0.2)
                        Text("整理范围")
                            .appFont(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.73, green: 0.70, blue: 1.0))
                        Text("按实际主题迁移 Markdown 笔记，原始文件保持只读。")
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(height: 178)

                Divider().opacity(0.25)

                HStack {
                    Text("open-computer-use")
                    Spacer()
                    Text("仅在本机显示")
                }
                .appFont(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
            }
            .frame(width: 376, height: 276)
            .foregroundStyle(.white)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(radius: 18, y: 8)
        } else {
            Button(action: model.toggleVisualSession) {
                HStack(spacing: 8) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text(session.title)
                        .appFont(.caption.weight(.semibold))
                    Image(systemName: "chevron.up")
                        .appFont(.caption2)
                }
                .padding(.horizontal, 13)
                .frame(width: 168, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10), in: Capsule())
            .shadow(radius: 12, y: 5)
        }
    }
}
