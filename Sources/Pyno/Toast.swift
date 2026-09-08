import AppKit

/// A small caption that appears next to the pointer for a moment — used to confirm
/// that something landed on the clipboard or on disk, without a modal or a banner.
@MainActor
final class Toast {
    static let shared = Toast()

    private var panel: NSPanel?
    private var dismissal: DispatchWorkItem?

    private init() {}

    func show(_ message: String) {
        dismissal?.cancel()

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.sizeToFit()

        let padding = NSSize(width: 20, height: 12)
        let size = NSSize(
            width: ceil(label.frame.width) + padding.width,
            height: ceil(label.frame.height) + padding.height
        )

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.86).cgColor
        content.layer?.cornerRadius = size.height / 2
        content.layer?.cornerCurve = .continuous
        label.frame.origin = NSPoint(
            x: padding.width / 2,
            y: (size.height - label.frame.height) / 2
        )
        content.addSubview(label)

        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setContentSize(size)
        panel.contentView = content
        panel.setFrameOrigin(origin(for: size))
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.09
            panel.animator().alphaValue = 1
        }

        let dismissal = DispatchWorkItem { [weak self] in self?.hide() }
        self.dismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: dismissal)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        return panel
    }

    /// Just below and to the right of the pointer, kept inside the current screen.
    private func origin(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        var point = NSPoint(x: mouse.x + 14, y: mouse.y - size.height - 12)

        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            point.x = min(max(point.x, visible.minX + 6), visible.maxX - size.width - 6)
            point.y = min(max(point.y, visible.minY + 6), visible.maxY - size.height - 6)
        }
        return point
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }
}
