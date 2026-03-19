import SwiftUI
import AppKit

/// Borderless panels can't become key by default — override so buttons work.
private class ClickablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class FocusPopupController {
    private var panel: NSPanel?

    func show(
        appName: String,
        elapsed: TimeInterval,
        snoozeMinutes: Int,
        onDismiss: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    ) {
        let view = FocusPopupView(
            appName: appName,
            elapsed: elapsed,
            snoozeMinutes: snoozeMinutes,
            onDismiss: { [weak self] in
                onDismiss()
                self?.dismiss()
            },
            onSnooze: { [weak self] in
                onSnooze()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView:
            view
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        // Let the hosting view compute its intrinsic size so the panel
        // frame matches the SwiftUI content — otherwise buttons outside
        // the contentRect are invisible to AppKit hit-testing.
        let size = hostingView.fittingSize

        let panel = ClickablePanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }
}
