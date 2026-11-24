import Cocoa
import SwiftUI
import CleaningCore

/// State behind the launcher window: permission status and the chosen timer.
final class LauncherModel: ObservableObject {
    enum TimerChoice: Hashable {
        case preset(TimeInterval)
        case custom
    }

    @Published private(set) var accessibilityGranted = false
    @Published var timeout: TimeInterval {
        didSet { SessionConfig.saveTimeout(timeout) }
    }
    @Published var isCustom: Bool
    let holdDuration: TimeInterval
    var onStart: (() -> Void)?

    private var pollTimer: Timer?

    init() {
        let config = SessionConfig.load()
        timeout = config.timeout
        holdDuration = config.holdDuration
        isCustom = !TimeoutOptions.presets.contains(config.timeout)
    }

    var timerChoice: TimerChoice {
        get { isCustom ? .custom : .preset(timeout) }
        set {
            switch newValue {
            case .preset(let seconds):
                isCustom = false
                timeout = seconds
            case .custom:
                isCustom = true
            }
        }
    }

    func incrementTimeout() { timeout = TimeoutOptions.increment(timeout) }
    func decrementTimeout() { timeout = TimeoutOptions.decrement(timeout) }

    /// Accessibility can be granted while the window is open; reflect it live.
    func startPolling() {
        refreshPermission()
        stopPolling()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshPermission() }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func openAccessibilitySettings() {
        _ = Permissions.accessibilityGranted(prompt: true) // adds the app to the list
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func start() { onStart?() }

    private func refreshPermission() {
        let granted = Permissions.accessibilityGranted(prompt: false)
        if granted != accessibilityGranted { accessibilityGranted = granted }
    }
}

// MARK: - View

struct LauncherView: View {
    @ObservedObject var model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            permissionStatus
            timerSection
            exitsSection
            startButton
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(width: 440)
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.72, blue: 0.85),
                                              Color(red: 0.20, green: 0.42, blue: 0.90)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text("BetterClean").font(.title2.weight(.bold))
                Text("Clean your keyboard, trackpad and screen without triggering anything.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var permissionStatus: some View {
        if model.accessibilityGranted {
            Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(.green)
        } else {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accessibility access needed")
                        .font(.callout.weight(.semibold))
                    Text("BetterClean needs it to block the keyboard and trackpad while you clean.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Accessibility Settings") { model.openAccessibilitySettings() }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Auto-unlock after").font(.headline)
            Picker("Auto-unlock after", selection: $model.timerChoice) {
                ForEach(TimeoutOptions.presets, id: \.self) { seconds in
                    Text(TimeFormatting.duration(seconds)).tag(LauncherModel.TimerChoice.preset(seconds))
                }
                Text("Custom").tag(LauncherModel.TimerChoice.custom)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if model.isCustom {
                HStack {
                    Text(TimeFormatting.duration(model.timeout))
                        .font(.title3.monospacedDigit().weight(.medium))
                    Spacer()
                    Stepper("Custom time",
                            onIncrement: model.incrementTimeout,
                            onDecrement: model.decrementTimeout)
                        .labelsHidden()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Text("Input comes back on its own after this time, even if Touch ID doesn't work. Up to 15 min.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var exitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ways to exit").font(.headline)
            ExitRow(symbol: "touchid", title: "Touch ID",
                    detail: "Touch the sensor lightly with a registered finger. Don't press it.")
            ExitRow(symbol: "hand.tap", title: "Trackpad hold",
                    detail: "Press and hold the trackpad for \(TimeFormatting.duration(model.holdDuration)).")
            ExitRow(symbol: "timer", title: "Timer",
                    detail: "Unlocks automatically after \(TimeFormatting.duration(model.timeout)).")
        }
    }

    private var startButton: some View {
        VStack(spacing: 8) {
            Button(action: model.start) {
                Label("Start Cleaning Mode", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!model.accessibilityGranted)

            Text("BetterClean stays in the menu bar after you close this window.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct ExitRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Window

/// Shown at launch and whenever the app is opened again (Finder, `open`,
/// Spotlight). The menu bar icon alone is easy to miss, for example behind the notch.
final class LauncherWindowController: NSWindowController, NSWindowDelegate {
    var onStart: (() -> Void)?
    private let model = LauncherModel()

    init() {
        let hosting = NSHostingController(rootView: LauncherView(model: model))
        hosting.sizingOptions = [.preferredContentSize] // window follows the view (Custom row appears/disappears)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self

        model.onStart = { [weak self] in
            self?.window?.close()
            // Let the click's mouse-up finish before the event tap goes live.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.onStart?() }
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func present() {
        model.startPolling()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.stopPolling()
    }
}
