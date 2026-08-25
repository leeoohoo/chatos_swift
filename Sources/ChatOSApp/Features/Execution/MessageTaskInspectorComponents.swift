import ChatOSCore
import SwiftUI

struct TaskInspectorTitle: View {
    let task: MessageTask

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(task.title).font(.title3.weight(.semibold))
            Text(task.id).font(.caption.monospaced()).foregroundStyle(.tertiary)
        }
    }
}

struct TaskRunEventTimeline: View {
    let events: [MessageTaskRunEvent]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            Text("运行事件 · \(events.count)").font(.subheadline.weight(.semibold))
            ForEach(events) { event in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(AppPalette.ai.opacity(0.75))
                        .frame(width: 7, height: 7)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.eventType).font(.caption.weight(.semibold))
                            Spacer()
                            if let createdAt = event.createdAt {
                                Text(createdAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        if let message = event.message {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}
