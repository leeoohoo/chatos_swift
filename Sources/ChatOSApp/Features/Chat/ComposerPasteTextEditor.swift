import AppKit
import SwiftUI

enum ComposerPasteContent {
    case files([URL])
    case image(data: Data, mimeType: String, suggestedName: String)
    case document(data: Data, mimeType: String, suggestedName: String)
    case longText(String)
}

struct ComposerPasteTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    var onPasteContent: (ComposerPasteContent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = PasteAwareTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 0, height: 7)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 34)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.string = text
        textView.onSubmit = onSubmit
        textView.onPasteContent = onPasteContent
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PasteAwareTextView else { return }
        context.coordinator.parent = self
        textView.onSubmit = onSubmit
        textView.onPasteContent = onPasteContent
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(
                NSRange(location: min(selection.location, text.utf16.count), length: 0)
            )
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerPasteTextEditor

        init(parent: ComposerPasteTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private final class PasteAwareTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onPasteContent: ((ComposerPasteContent) -> Void)?
    private var didRequestInitialFocus = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didRequestInitialFocus else { return }
        didRequestInitialFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommandPaste = event.type == .keyDown
            && modifiers == .command
            && event.charactersIgnoringModifiers?.lowercased() == "v"
        if isCommandPaste {
            paste(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        let insertsNewline = event.modifierFlags.contains(.shift)
        if isReturn, !insertsNewline, !hasMarkedText() {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        if consumePasteboard(.general) { return }
        super.paste(sender)
    }

    private func consumePasteboard(_ pasteboard: NSPasteboard) -> Bool {
        let fileURLs = Self.fileURLs(from: pasteboard)
        if !fileURLs.isEmpty {
            onPasteContent?(.files(fileURLs))
            return true
        }

        let pngType = NSPasteboard.PasteboardType("public.png")
        if let data = pasteboard.data(forType: pngType), !data.isEmpty {
            onPasteContent?(.image(
                data: data,
                mimeType: "image/png",
                suggestedName: Self.timestampedName("粘贴的图片", extension: "png")
            ))
            return true
        }

        let jpegType = NSPasteboard.PasteboardType("public.jpeg")
        if let data = pasteboard.data(forType: jpegType), !data.isEmpty {
            onPasteContent?(.image(
                data: data,
                mimeType: "image/jpeg",
                suggestedName: Self.timestampedName("粘贴的图片", extension: "jpg")
            ))
            return true
        }

        if let tiff = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiff),
           let png = image.pngData {
            onPasteContent?(.image(
                data: png,
                mimeType: "image/png",
                suggestedName: Self.timestampedName("粘贴的图片", extension: "png")
            ))
            return true
        }

        if let pastedText = pasteboard.string(forType: .string),
           pastedText.count >= ConversationSessionViewModel.longPasteCharacterThreshold
            || pastedText.utf8.count >= ConversationSessionViewModel.longPasteByteThreshold {
            onPasteContent?(.longText(pastedText))
            return true
        }

        if let pdf = pasteboard.data(forType: .pdf), !pdf.isEmpty {
            onPasteContent?(.document(
                data: pdf,
                mimeType: "application/pdf",
                suggestedName: Self.timestampedName("粘贴的文档", extension: "pdf")
            ))
            return true
        }

        return false
    }

    private static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        if let values = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !values.isEmpty {
            return values
        }

        if let value = pasteboard.string(forType: .fileURL),
           let url = URL(string: value), url.isFileURL {
            return [url]
        }

        let legacyFilenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        guard let paths = pasteboard.propertyList(
            forType: legacyFilenamesType
        ) as? [String] else { return [] }
        return paths.map { URL(fileURLWithPath: $0) }
    }

    private static func timestampedName(_ prefix: String, extension fileExtension: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "\(prefix) \(formatter.string(from: Date())).\(fileExtension)"
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
