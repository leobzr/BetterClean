# BetterClean (prototype)

Menu bar app that blacks out every display and blocks keyboard and trackpad input so a MacBook can be wiped. Exit with Touch ID, by holding the trackpad down for 3 s, or by waiting for the timer.

> Meant for quick dry or lightly damp wipes. Apple recommends powering off before cleaning with liquid.
> Last resort if anything goes wrong: hold the power button to force a shutdown.

## Build and run

Needs macOS 13+, Swift 5.10+ (the Command Line Tools are enough, no Xcode needed).

```sh
scripts/build-app.sh            # debug build
scripts/build-app.sh release    # release build
open build/BetterClean.app      # sparkles icon in the menu bar → Start Cleaning Mode
open build/BetterClean.app --args --start   # start a session right away
scripts/test.sh                 # unit tests for CleaningCore
```

**Accessibility permission:** grant it in System Settings › Privacy & Security › Accessibility. The build is ad-hoc signed, so macOS treats each rebuild as a new app: remove BetterClean from the list and add it again after rebuilding. Set `SIGN_IDENTITY` to a code-signing certificate to avoid this.

**Settings** (for prototyping):

```sh
defaults write local.betterclean.prototype timeoutSeconds -float 60
defaults write local.betterclean.prototype holdSeconds -float 3
defaults write local.betterclean.prototype useSystemPrompt -bool true   # system dialog instead of embedded Touch ID view
defaults delete local.betterclean.prototype                             # back to defaults
```

Logs: `log stream --predicate 'subsystem == "local.betterclean.prototype"'`

## Layout

| Component | File | Role |
|---|---|---|
| `CleaningSession` | `Sources/BetterClean/CleaningSession.swift` | Starts and ends a session; ending restores input first |
| `InputBlocker` | `Sources/BetterClean/InputBlocker.swift` | Event tap that swallows input; lets everything through once past its deadline |
| `OverlayController` | `Sources/BetterClean/OverlayController.swift` | Black windows per display, status card, embedded Touch ID view |
| `BiometricUnlocker` | `Sources/BetterClean/BiometricUnlocker.swift` | Biometrics-only prompt, re-armed with backoff after failures |
| `SystemGuards` | `Sources/BetterClean/SystemGuards.swift` | Accessibility check, Secure Input check, display-sleep assertion, Caps Lock restore |
| `CleaningCore` | `Sources/CleaningCore/` | Pure, tested logic: long-press detector, retry policy, session clock |

Rule: any change to the tap or exit logic must keep **both** fallbacks (timer and trackpad hold).

## Prototype test checklist

Main question: **does Touch ID work while the tap and overlay are up?** Yes (tested 2026-11-23, MacBook Air).

- [x] A touch with a registered finger exits; other fingers and non-fingerprint touches don't
- [ ] Optional: with `useSystemPrompt` on, is the system Touch ID dialog visible above the overlay? (Not needed: the embedded view works and is the default.)
- [x] A failed round (wrong fingers) pauses Touch ID; the trackpad hold exits, and the next session's Touch ID works without the password. (Earlier design re-armed after 5 s; the second failed round locked Touch ID.)
- [x] Trackpad hold for 3 s exits
- [x] Timer exits on its own
- [x] Keyboard fully blocked
- [x] Trackpad gestures blocked
- [x] Caps Lock state is the same after exit as before
- [x] Pressing the power button (= Touch ID key) ends the session and input comes back; the Mac doesn't sleep. Which signal ends it is still to be confirmed in the log
- [x] Plug in or unplug a display mid-session: every screen stays covered
- [~] Lid open, external monitor as main display, pointer last on the monitor: inconsistent. The same build failed in one test and worked in a later one (2026-11-23, sessions ended by Touch ID). Cause unknown; the trackpad hold and timer always work.
- [x] Display doesn't dim during a long session
- [x] Three-finger drag turned on: wiping the trackpad doesn't trigger the hold exit
- [x] Lid closed with an external display: fallbacks work

Known limitation: with an external monitor as the main display, Touch ID sometimes doesn't respond (cause unknown); use the trackpad hold.

Not yet built: global keyboard shortcut (planned for later). Touch Bar Macs: the Touch Bar isn't blocked.
