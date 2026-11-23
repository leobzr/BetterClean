import Cocoa

/// Small window shown at launch and whenever the app is opened again
/// (Finder, `open`, Spotlight). The menu bar icon alone is easy to miss,
/// for example when it's hidden behind the notch.
final class LauncherWindowController: NSWindowController, NSWindowDelegate {
    var onStart: (() -> Void)?

    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "Open Accessibility Settings", target: nil, action: nil)
    private let startButton = NSButton(title: "Start Cleaning Mode", target: nil, action: nil)
    private var pollTimer: Timer?

    init(timeout: TimeInterval, holdDuration: TimeInterval) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "BetterClean"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent(timeout: timeout, holdDuration: holdDuration)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func present() {
        refreshPermission()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        startPolling()
    }

    func windowWillClose(_ notification: Notification) {
        stopPolling()
    }

    // MARK: - Private

    private func buildContent(timeout: TimeInterval, holdDuration: TimeInterval) {
        let title = NSTextField(labelWithString: "Clean your Mac without triggering anything")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: """
            Cleaning mode blacks out the screen and blocks the keyboard and trackpad. \
            To exit, touch the Touch ID sensor lightly (don't press it), hold the trackpad \
            down for \(Int(holdDuration)) seconds, or wait \(Int(timeout)) seconds.

            BetterClean stays in the menu bar (✦ icon) after you close this window.
            """)
        body.preferredMaxLayoutWidth = 372

        permissionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        permissionButton.target = self
        permissionButton.action = #selector(openAccessibilitySettings)
        permissionButton.bezelStyle = .rounded

        startButton.target = self
        startButton.action = #selector(start)
        startButton.bezelStyle = .rounded
        startButton.keyEquivalent = "\r"

        let permissionRow = NSStackView(views: [permissionLabel, permissionButton])
        permissionRow.orientation = .horizontal
        permissionRow.spacing = 8

        let stack = NSStackView(views: [title, body, permissionRow, startButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.setCustomSpacing(22, after: permissionRow)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
        ])
        window?.contentView = content
    }

    /// Accessibility can be granted while the window is open; reflect it live.
    private func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshPermission() }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshPermission() {
        let granted = Permissions.accessibilityGranted(prompt: false)
        permissionLabel.stringValue = granted ? "✓ Accessibility access granted" : "⚠︎ Accessibility access needed"
        permissionLabel.textColor = granted ? .systemGreen : .systemOrange
        permissionButton.isHidden = granted
        startButton.isEnabled = granted
    }

    @objc private func openAccessibilitySettings() {
        _ = Permissions.accessibilityGranted(prompt: true) // adds the app to the list
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func start() {
        window?.close()
        // Let the button's mouse-up finish before the event tap goes live.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.onStart?() }
    }
}
