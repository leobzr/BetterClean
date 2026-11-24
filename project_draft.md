# Project: Laptop Cleaning Mode (macOS)

## Goal

A small macOS app that puts the Mac into a safe "cleaning mode" so the keyboard, trackpad and screen can be wiped without triggering input. The user exits cleaning mode with Touch ID.

Target: MacBooks with a Touch ID sensor (Apple Silicon first). Windows/Linux support is out of scope for now and would need a separate codebase.

## Core behavior

1. **Enter cleaning mode** (menu bar item, global shortcut, or app launch).
2. **Black out the screen:** borderless, pure black window covering every display, above all other windows. Black makes smudges and dust on the display easy to see.
3. **Block input:** swallow all keyboard events (including media, brightness and function keys) and trackpad/mouse events (clicks, movement, scroll, gestures where possible).
4. **Exit with Touch ID:** user touches (not presses) the Touch ID sensor, app authenticates, input is restored and the overlay closes.
5. **Safety fallback:** auto-exit after a timeout (default 20 seconds, chosen in the app window: 20 s, 1, 3 or 5 min, or custom up to 15 min), plus an emergency exit: press and hold the trackpad for 3 seconds. (A key combo was dropped: wiping the keyboard can press keys by accident.)

## Technical approach

- **Language/UI:** Swift, SwiftUI for settings, AppKit `NSWindow` for the overlay. Menu bar app (`LSUIElement = YES`).
- **Overlay window:**
  - `NSWindow` with `.borderless` style, black background, one per `NSScreen`.
  - Window level high enough to cover the menu bar and Dock (for example `.screenSaver`), with `collectionBehavior` set to `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
  - Hide the cursor (`NSCursor.hide()`), and consider `NSApplication.presentationOptions` to hide the Dock/menu bar and disable process switching.
- **Input blocking:**
  - Active `CGEventTap` (`CGEvent.tapCreate`, `.cghidEventTap` or `.cgSessionEventTap`, `.headInsertEventTap`, `.defaultTap`) that returns `nil` for blocked events.
  - Event mask should cover: `keyDown`, `keyUp`, `flagsChanged`, `NX_SYSDEFINED` (media/brightness keys, type 14), mouse moved/dragged, left/right/other mouse down/up, scroll wheel, and gesture types where available.
  - Handle `tapDisabledByTimeout` and `tapDisabledByUserInput` by re-enabling the tap.
  - Keep the tap callback fast; never block in it.
  - Requires the **Accessibility** permission (`AXIsProcessTrustedWithOptions` to prompt). Check permission before entering cleaning mode and guide the user if missing.
- **Touch ID:**
  - `LocalAuthentication` framework, `LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, ...)`.
  - Use the biometrics-only policy, since the password fallback would need the keyboard, which is blocked.
  - Provide a clear `localizedReason` string (for example "Exit cleaning mode").
  - On failure or lockout (`LAError.biometryLockout`, `.authenticationFailed`), retry the prompt after a short delay rather than giving up. If biometry is locked out, rely on the timeout fallback.
- **Distribution:** Accessibility-based input blocking is generally not allowed in the Mac App Store sandbox. Plan for a Developer ID signed, notarized download.

## Known pitfalls (design around these)

1. **The Touch ID sensor is the power button.** Pressing it sleeps/locks the display, and holding it forces shutdown. The app cannot intercept this. Show a hint on the overlay: "Touch lightly, don't press."
2. **Wiping the sensor causes failed reads.** Several failures push macOS toward password fallback or biometry lockout. Re-arm the Touch ID prompt as needed and keep the timeout fallback.
3. **The system Touch ID dialog may render behind the overlay.** Test window levels carefully. If the system prompt is hidden, lower the overlay level or temporarily order the overlay back while the prompt is up.
4. **Never trap the user.** Always have the timeout and emergency exit. If the process crashes, macOS removes the event tap automatically, which is a good default, but hangs must be avoided.
5. **Trackpad system gestures** (Mission Control, App Exposé, etc.) may not be fully blockable. Use presentation options to reduce their effect and document any that leak through.
6. **Touch Bar Macs:** the Touch Bar is not a keyboard and will fire actions when wiped. Out of scope for MVP, but note it in the README.
7. **Multiple displays:** cover every screen, and react to screens being connected or disconnected during cleaning mode.

## MVP scope

- [x] Menu bar app with "Start Cleaning Mode" item
- [x] Accessibility permission check and onboarding (launcher window)
- [x] Black overlay on all displays, cursor hidden
- [x] Event tap blocking keyboard, media keys and trackpad/mouse
- [x] Touch ID exit; after one failed round it pauses (a second round triggered macOS's password lockout)
- [x] Timeout auto-exit (default 20 s, configurable) with a visible countdown
- [x] Emergency exit: trackpad hold for 3 s
- [x] Overlay hint text: "Touch the sensor lightly to exit. Don't press it."

## Later ideas

- Global keyboard shortcut to start cleaning from any app (moved out of the MVP on 2026-11-23: the menu bar icon is enough for now)
- Optional dim gray mode instead of pure black (for seeing keys under keyboard backlight)
- Turn keyboard backlight to max while cleaning
- Cleaning reminders on a schedule
- Windows version (low-level keyboard hook + Windows Hello; note Ctrl+Alt+Del can never be blocked)

## Notes for Claude Code

- Keep the input-blocking and Touch ID logic in small, testable components (for example `InputBlocker`, `OverlayController`, `BiometricUnlocker`, `CleaningSession`).
- Any change to the event tap or exit logic must preserve both fallbacks (timeout and trackpad hold).
- Apple's own guidance is to power off before cleaning with liquid. The app is meant for quick dry or lightly damp wipes; mention this in the README.