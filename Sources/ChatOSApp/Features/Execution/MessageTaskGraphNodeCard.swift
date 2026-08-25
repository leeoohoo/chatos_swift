import ChatOSCore
import SwiftUI

struct MessageTaskGraphNodeCard: View {
    let node: MessageTaskGraphNode
    let renderScale: Double
    let isSelected: Bool
    let isDimmed: Bool
    let onSelect: () -> Void
    let onOpenProcess: () -> Void
    let onOpenDetail: () -> Void
    let onOpenRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: scaled(9)) {
            HStack(spacing: scaled(7)) {
                Circle()
                    .fill(statusColor)
                    .frame(width: scaled(8), height: scaled(8))
                Text(statusTitle)
                    .font(.system(size: scaledFont(11), weight: .medium))
                    .foregroundStyle(statusColor)
                if node.isCurrentMessage {
                    Text("当前消息")
                        .font(.system(size: scaledFont(10), weight: .semibold))
                        .foregroundStyle(AppPalette.ai)
                }
                Spacer()
                if node.groupedTasks.count > 1 {
                    Text("\(node.groupedTasks.count) 阶段")
                        .font(.system(size: scaledFont(10)))
                        .foregroundStyle(.secondary)
                }
            }
            Text(node.task.title)
                .font(.system(size: scaledFont(13), weight: .semibold))
                .lineLimit(2)
            Text(node.task.description ?? node.task.objective ?? "暂无任务描述")
                .font(.system(size: scaledFont(11)))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: scaled(6)) {
                actionButton("过程", action: onOpenProcess)
                actionButton(
                    node.task.normalizedStatus == "blocked" ? "处理阻塞" : "详情",
                    action: onOpenDetail
                )
                actionButton("运行", action: onOpenRun)
                    .disabled(node.task.lastRunID == nil)
            }
        }
        .padding(scaled(12))
        .frame(
            width: MessageTaskGraphLayout.nodeSize.width * renderScale,
            height: MessageTaskGraphLayout.nodeSize.height * renderScale,
            alignment: .topLeading
        )
        .background(
            Color(nsColor: .windowBackgroundColor),
            in: RoundedRectangle(cornerRadius: scaled(11))
        )
        .overlay {
            RoundedRectangle(cornerRadius: scaled(11)).stroke(
                isSelected ? statusColor : Color(nsColor: .separatorColor),
                lineWidth: scaled(isSelected ? 2 : 1)
            )
        }
        .shadow(
            color: .black.opacity(isSelected ? 0.12 : 0.04),
            radius: scaled(isSelected ? 8 : 3),
            y: scaled(2)
        )
        .opacity(isDimmed ? 0.42 : 1)
        .contentShape(RoundedRectangle(cornerRadius: scaled(11)))
        .onTapGesture(perform: onSelect)
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: scaledFont(10), weight: .medium))
                .padding(.horizontal, scaled(7))
                .padding(.vertical, scaled(3))
                .background(
                    Color.accentColor.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: scaled(5))
                )
        }
        .buttonStyle(.plain)
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        value * renderScale
    }

    private func scaledFont(_ value: CGFloat) -> CGFloat {
        max(4, scaled(value))
    }

    private var statusTitle: String {
        switch node.task.normalizedStatus {
        case "completed", "succeeded", "success", "done": "已完成"
        case "running", "processing", "in_progress", "doing": "运行中"
        case "blocked": "被阻塞"
        case "failed", "error": "失败"
        case "cancelled", "canceled": "已取消"
        default: "等待执行"
        }
    }

    private var statusColor: Color {
        switch node.task.normalizedStatus {
        case "completed", "succeeded", "success", "done": .green
        case "running", "processing", "in_progress", "doing": AppPalette.ai
        case "blocked": .orange
        case "failed", "error", "cancelled", "canceled": .red
        default: .secondary
        }
    }
}

struct DotGridSurface: View {
    var body: some View {
        Canvas { context, size in
            for x in stride(from: CGFloat(10), to: size.width, by: 20) {
                for y in stride(from: CGFloat(10), to: size.height, by: 20) {
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                    context.fill(dot, with: .color(.secondary.opacity(0.16)))
                }
            }
        }
    }
}
