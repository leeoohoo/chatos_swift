import AppKit
import ChatOSCore
import SwiftUI

struct ProjectPlanDocumentsView: View {
    @ObservedObject var viewModel: ProjectPlanViewModel

    var body: some View {
        Group {
            if viewModel.documents.isEmpty {
                ContentUnavailableView(
                    "这个需求还没有技术文档",
                    systemImage: "doc.text"
                )
            } else {
                HSplitView {
                    documentList
                        .frame(minWidth: 230, idealWidth: 270, maxWidth: 330)
                    documentContent
                        .frame(minWidth: 420)
                }
            }
        }
        .workspaceFill()
    }

    private var documentList: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("技术文档").font(.headline)
                    Text("\(viewModel.documents.count) 份文档")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            Divider()
            List(viewModel.documents, selection: $viewModel.selectedDocumentID) { document in
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(documentTypeTitle(document.type))
                        Text("v\(document.version)")
                        if let updatedAt = document.updatedAt {
                            Text(updatedAt, style: .date)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
                .tag(document.id)
            }
            .listStyle(.sidebar)
        }
        .workspaceFill()
    }

    @ViewBuilder
    private var documentContent: some View {
        if let document = viewModel.selectedDocument {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(document.title).font(.headline)
                        HStack(spacing: 7) {
                            StatusCapsule(title: documentTypeTitle(document.type), color: AppPalette.ai)
                            StatusCapsule(title: document.format, color: .secondary)
                            StatusCapsule(title: "v\(document.version)", color: .secondary)
                        }
                    }
                    Spacer()
                }
                .padding(16)
                Divider()
                ScrollView([.horizontal, .vertical]) {
                    DocumentBody(document: document)
                        .padding(20)
                        .frame(maxWidth: 980, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .workspaceFill(alignment: .topLeading)
            }
        } else {
            ContentUnavailableView("选择一份文档", systemImage: "doc.text")
        }
    }

    private func documentTypeTitle(_ type: String) -> String {
        switch type.lowercased() {
        case "technical_overview": "技术概览"
        case "implementation_plan": "实施计划"
        case "ui_svg_preview": "界面设计"
        case "architecture_diagram": "架构图"
        case "flowchart": "流程图"
        case "sequence_diagram": "时序图"
        case "api_design": "接口设计"
        case "data_model": "数据模型"
        case "risk_notes": "风险说明"
        default: "技术文档"
        }
    }
}

private struct DocumentBody: View {
    let document: ProjectRequirementDocument

    var body: some View {
        if isSVG, let image = NSImage(data: Data(svgMarkup.utf8)) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(minWidth: 600, minHeight: 360)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
        } else if document.content.isEmpty {
            Text("暂无内容").foregroundStyle(.secondary)
        } else {
            MarkdownDocumentView(markdown: document.content)
        }
    }

    private var isSVG: Bool {
        document.type.lowercased().contains("svg")
            || document.format.lowercased() == "svg"
            || document.content.localizedCaseInsensitiveContains("<svg")
    }

    private var svgMarkup: String {
        guard let start = document.content.range(of: "<svg", options: .caseInsensitive),
              let end = document.content.range(of: "</svg>", options: [.caseInsensitive, .backwards]) else {
            return document.content
        }
        return String(document.content[start.lowerBound..<end.upperBound])
    }
}
