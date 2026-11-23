import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var session: CleaningSession?
    private var launcher: LauncherWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = SessionConfig.load()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "BetterClean")

        let menu = NSMenu()
        let start = NSMenuItem(title: "Start Cleaning Mode", action: #selector(startCleaning), keyEquivalent: "")
        start.target = self
        menu.addItem(start)
        let show = NSMenuItem(title: "Show BetterClean Window", action: #selector(showLauncher), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let info = NSMenuItem(title: "Auto-unlock after \(Int(config.timeout))s", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit BetterClean", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item

        NSLog("BetterClean: launched (timeout \(Int(config.timeout))s, accessibility \(Permissions.accessibilityGranted(prompt: false) ? "granted" : "missing"))")

        // `open BetterClean.app --args --start` starts a session right away (handy while testing).
        if CommandLine.arguments.contains("--start") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.startCleaning() }
        } else {
            showLauncher()
        }
    }

    /// Opening the app again (Finder, `open`, Spotlight) while it's running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if session?.isActive != true { showLauncher() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        session?.end(.timeout)
    }

    @objc private func showLauncher() {
        if launcher == nil {
            let config = SessionConfig.load()
            let controller = LauncherWindowController(timeout: config.timeout, holdDuration: config.holdDuration)
            controller.onStart = { [weak self] in self?.startCleaning() }
            launcher = controller
        }
        launcher?.present()
    }

    @objc private func startCleaning() {
        guard session?.isActive != true else { return }
        let session = CleaningSession(config: SessionConfig.load())
        session.onEnded = { [weak self] _ in self?.session = nil }
        do {
            try session.start()
            self.session = session
        } catch {
            NSLog("BetterClean: could not start: \(error.localizedDescription)")
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Can't start cleaning mode"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
