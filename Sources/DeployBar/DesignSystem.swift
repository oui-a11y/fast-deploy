import SwiftUI

enum DeployBarTheme {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let panelRaised = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.5)
    static let accent = Color(red: 0.13, green: 0.36, blue: 0.86)
    static let cyan = Color(red: 0.05, green: 0.55, blue: 0.62)
    static let success = Color(red: 0.10, green: 0.55, blue: 0.28)
    static let danger = Color(red: 0.82, green: 0.18, blue: 0.16)
    static let warning = Color(red: 0.82, green: 0.50, blue: 0.08)
}

struct SurfaceModifier: ViewModifier {
    var radius: CGFloat = 8
    var fill: Color = DeployBarTheme.panel

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(DeployBarTheme.border, lineWidth: 1)
            }
    }
}

extension View {
    func deploySurface(radius: CGFloat = 8, fill: Color = DeployBarTheme.panel) -> some View {
        modifier(SurfaceModifier(radius: radius, fill: fill))
    }
}

struct AppSectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DeployBarTheme.accent)
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct StatusPill: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.22), lineWidth: 1)
            }
    }
}

struct MetadataChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(DeployBarTheme.cyan)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .deploySurface(fill: DeployBarTheme.panelRaised)
    }
}

struct ConsoleTextView: View {
    let text: String
    let placeholder: String

    var body: some View {
        ConsoleTextRepresentable(text: text, placeholder: placeholder)
            .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct ConsoleTextRepresentable: NSViewRepresentable {
    let text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.update(text: text, placeholder: placeholder)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(text: text, placeholder: placeholder)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var textView: NSTextView?
        private var displayedText: String?

        func update(text: String, placeholder: String) {
            guard let textView else { return }

            let nextText = text.isEmpty ? placeholder : text
            guard displayedText != nextText else { return }

            let shouldFollowTail = isScrolledNearBottom(textView)
            displayedText = nextText
            textView.string = nextText
            textView.textColor = text.isEmpty ? .secondaryLabelColor : .labelColor

            if shouldFollowTail {
                textView.scrollToEndOfDocument(nil)
            }
        }

        private func isScrolledNearBottom(_ textView: NSTextView) -> Bool {
            guard let scrollView = textView.enclosingScrollView else { return true }
            let visibleMaxY = scrollView.contentView.bounds.maxY
            let documentHeight = textView.bounds.height
            return documentHeight - visibleMaxY < 40
        }
    }
}
