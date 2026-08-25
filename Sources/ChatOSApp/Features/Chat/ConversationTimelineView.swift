import ChatOSCore
import SwiftUI

struct ConversationTimelineView: View {
    @ObservedObject var conversation: ConversationSessionViewModel
    let title: String
    let showsTaskState: Bool
    @State private var selectedProcessTurn: ConversationTurn?
    @State private var selectedTaskTurn: ConversationTurn?
    @State private var selectedTaskReply: TaskReplySelection?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ConversationHistoryStatusView(conversation: conversation)
            timeline
                .workspaceFill()
            ComposerView(conversation: conversation)
                .padding(16)
        }
        .workspaceFill()
        .background(Color(nsColor: .textBackgroundColor))
        .sheet(item: $selectedProcessTurn) { turn in
            if let service = conversation.turnProcessService {
                TurnProcessSheet(turn: turn, service: service)
            }
        }
        .sheet(item: $selectedTaskTurn) { turn in
            if let graphService = conversation.messageTaskGraphService {
                MessageTaskWorkspaceSheet(
                    turn: turn,
                    graphService: graphService,
                    projectExecutionService: conversation.projectExecutionService
                )
            }
        }
    }

    private var header: some View {
        HStack {
            Text(title).appFont(.subheadline.weight(.semibold))
            Spacer()
            if showsTaskState {
                Label("执行中 · 可发送引导", systemImage: "sparkles")
                    .appFont(.caption.weight(.medium))
                    .foregroundStyle(AppPalette.ai)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if conversation.hasOlder {
                            if conversation.isLoadingOlder {
                                ProgressView("正在加载更早消息…")
                                    .controlSize(.small)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Button("加载更早消息", systemImage: "arrow.up") {
                                    conversation.loadOlder()
                                }
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                            }
                        }

                        if conversation.turns.isEmpty {
                            ContentUnavailableView(
                                "开始一段新对话",
                                systemImage: "bubble.left.and.bubble.right",
                                description: Text("这个会话还没有消息。")
                            )
                            .frame(maxWidth: .infinity, minHeight: 300)
                        }

                        ForEach(conversation.turns) { turn in
                            TurnView(
                                turn: turn,
                                onOpenProcess: { selectedProcessTurn = turn },
                                onOpenTaskWorkspace: { selectedTaskTurn = turn },
                                expandedTaskReply: selectedTaskReply,
                                taskGraphService: conversation.messageTaskGraphService,
                                onToggleTaskReply: toggleTaskReply
                            )
                                .id(turn.id)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                }

                if conversation.unreadNewerCount > 0 {
                    Button("\(conversation.unreadNewerCount) 条新消息", systemImage: "arrow.down") {
                        conversation.markNewerContentRead()
                        scrollToSelected(using: proxy)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 10)
                }
            }
            .onAppear { scrollToSelected(using: proxy, animated: false) }
            .onChange(of: conversation.selectedTurnID) {
                scrollToSelected(using: proxy)
            }
        }
    }

    private func toggleTaskReply(
        _ turn: ConversationTurn,
        _ reply: ConversationAssistantReply,
        _ section: TaskReplyInspectorSection
    ) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if selectedTaskReply?.reply.id == reply.id,
               selectedTaskReply?.initialSection == section {
                selectedTaskReply = nil
            } else {
                selectedTaskReply = TaskReplySelection(
                    turn: turn,
                    reply: reply,
                    initialSection: section
                )
            }
        }
    }

    private func scrollToSelected(using proxy: ScrollViewProxy, animated: Bool = true) {
        guard let turnID = conversation.selectedTurnID else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(turnID, anchor: .center)
            }
        } else {
            proxy.scrollTo(turnID, anchor: .bottom)
        }
    }
}

struct TurnView: View {
    let turn: ConversationTurn
    let onOpenProcess: () -> Void
    let onOpenTaskWorkspace: () -> Void
    let expandedTaskReply: TaskReplySelection?
    let taskGraphService: (any MessageTaskGraphServicing)?
    let onToggleTaskReply: (
        ConversationTurn,
        ConversationAssistantReply,
        TaskReplyInspectorSection
    ) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            UserTurnMessageView(
                turn: turn,
                onOpenProcess: onOpenProcess,
                onOpenTaskGraph: onOpenTaskWorkspace
            )

            ForEach(displayReplies) { reply in
                if reply.taskCallback != nil {
                    TaskAgentReplyView(
                        reply: reply,
                        expandedSection: expandedSection(for: reply),
                        onToggleInspector: { section in
                            onToggleTaskReply(turn, reply, section)
                        }
                    )
                    if let selection = expandedSelection(for: reply),
                       let taskGraphService {
                        TaskReplyInlineInspectorView(
                            selection: selection,
                            requestedSection: selection.initialSection,
                            service: taskGraphService
                        )
                        .padding(.leading, 30)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } else {
                    AssistantReplyView(reply: reply)
                }
            }
        }
    }

    private var displayReplies: [ConversationAssistantReply] {
        if !turn.assistantReplies.isEmpty {
            return turn.assistantReplies
        }
        return turn.finalAssistantMessage.map {
            [ConversationAssistantReply(message: $0)]
        } ?? []
    }

    private func expandedSelection(
        for reply: ConversationAssistantReply
    ) -> TaskReplySelection? {
        guard expandedTaskReply?.reply.id == reply.id else { return nil }
        return expandedTaskReply
    }

    private func expandedSection(
        for reply: ConversationAssistantReply
    ) -> TaskReplyInspectorSection? {
        expandedSelection(for: reply)?.initialSection
    }
}
