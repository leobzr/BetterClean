import Cocoa
import LocalAuthentication
import LocalAuthenticationEmbeddedUI

/// Borderless windows can't become key by default; the main overlay needs to
/// so the embedded Touch ID view is active.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// One pure-black window per display, above the menu bar and Dock. The
/// display with the menu bar also gets the status card.
final class OverlayController {
    private var windows: [NSWindow] = []
    private var card: StatusCardView?
    private var authView: NSView?
    private var lastMessage = ""

    func show() {
        rebuild()
    }

    /// Called again when displays are connected or disconnected.
    func rebuild() {
        closeWindows()
        for (index, screen) in NSScreen.screens.enumerated() {
            let window = OverlayWindow(contentRect: screen.frame,
                                       styleMask: .borderless,
                                       backing: .buffered,
                                       defer: false)
            window.setFrame(screen.frame, display: false)
            window.level = .screenSaver
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let content = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            content.wantsLayer = true
            content.layer?.backgroundColor = NSColor.black.cgColor
            window.contentView = content

            if index == 0 { // NSScreen.screens[0] holds the menu bar
                let card = StatusCardView()
                card.translatesAutoresizingMaskIntoConstraints = false
                content.addSubview(card)
                NSLayoutConstraint.activate([
                    card.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                    card.centerYAnchor.constraint(equalTo: content.centerYAnchor),
                    card.widthAnchor.constraint(equalToConstant: 380),
                ])
                card.setAuthView(authView)
                card.setMessage(lastMessage)
                self.card = card
            }
            window.orderFrontRegardless()
            windows.append(window)
        }
        windows.first?.makeKeyAndOrderFront(nil)
    }

    func close() {
        closeWindows()
        authView = nil
        lastMessage = ""
    }

    /// Pass nil to fall back to the system Touch ID dialog.
    func installAuthView(for context: LAContext?) {
        if let context {
            authView = LAAuthenticationView(context: context, controlSize: .large)
        } else {
            authView = nil
        }
        card?.setAuthView(authView)
    }

    func update(elapsed: String, autoUnlockIn: String, holdRemaining: String?) {
        card?.update(elapsed: elapsed, autoUnlockIn: autoUnlockIn, holdRemaining: holdRemaining)
    }

    func setMessage(_ message: String) {
        lastMessage = message
        card?.setMessage(message)
    }

    private func closeWindows() {
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows.removeAll()
        card = nil
    }
}

/// Dim, low-contrast card so it doesn't hide smudges in the middle of the screen.
private final class StatusCardView: NSView {
    private let elapsedLabel = StatusCardView.label(size: 44, weight: .light, monospaced: true)
    private let timerLabel = StatusCardView.label(size: 13)
    private let authContainer = NSView()
    private let hintLabel = StatusCardView.label(size: 14)
    private let fallbackLabel = StatusCardView.label(size: 12)
    private let messageLabel = StatusCardView.label(size: 12)

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor
        layer?.cornerRadius = 18

        let title = StatusCardView.label(size: 15, weight: .semibold)
        title.stringValue = "Cleaning mode"
        hintLabel.stringValue = "Touch the sensor lightly to exit. Don't press it."
        fallbackLabel.stringValue = "Or press and hold the trackpad."

        authContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            authContainer.widthAnchor.constraint(equalToConstant: 64),
            authContainer.heightAnchor.constraint(equalToConstant: 64),
        ])

        let stack = NSStackView(views: [title, elapsedLabel, timerLabel, authContainer,
                                        hintLabel, fallbackLabel, messageLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(18, after: timerLabel)
        stack.setCustomSpacing(18, after: authContainer)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func update(elapsed: String, autoUnlockIn: String, holdRemaining: String?) {
        elapsedLabel.stringValue = elapsed
        timerLabel.stringValue = "Unlocks automatically in \(autoUnlockIn)"
        fallbackLabel.stringValue = holdRemaining.map { "Keep holding… \($0)" }
            ?? "Or press and hold the trackpad."
    }

    func setMessage(_ message: String) {
        messageLabel.stringValue = message
        messageLabel.isHidden = message.isEmpty
    }

    func setAuthView(_ view: NSView?) {
        authContainer.subviews.forEach { $0.removeFromSuperview() }
        guard let view else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        authContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: authContainer.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: authContainer.centerYAnchor),
            view.widthAnchor.constraint(equalTo: authContainer.widthAnchor),
            view.heightAnchor.constraint(equalTo: authContainer.heightAnchor),
        ])
    }

    private static func label(size: CGFloat, weight: NSFont.Weight = .regular,
                              monospaced: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: "")
        field.font = monospaced
            ? .monospacedDigitSystemFont(ofSize: size, weight: weight)
            : .systemFont(ofSize: size, weight: weight)
        field.textColor = NSColor(white: 0.55, alpha: 1)
        field.alignment = .center
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.preferredMaxLayoutWidth = 330
        return field
    }
}
