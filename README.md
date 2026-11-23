# BetterClean (prototype)

Menu bar app that blacks out every display and blocks keyboard and trackpad input so a MacBook can be wiped. Exit with Touch ID, by holding the trackpad down for 3 s, or by waiting for the timer.

> Meant for quick dry or lightly damp wipes. Apple recommends powering off before cleaning with liquid.
> Last resort if anything goes wrong: hold the power button to force a shutdown.

## Build and run

Needs macOS 13+, Swift 5.10+ (the Command Line Tools are enough, no Xcode needed).

```sh
scripts/build-app.sh            # debug: auto-unlock after 20 s
scripts/build-app.sh release    # release: auto-unlock after 180 s
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

Logs: `log stream --predicate 'eventMessage CONTAINS "BetterClean"'`

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

Main question: **does Touch ID work while the tap and overlay are up?**

- [ ] Embedded Touch ID view appears on the card, and a light touch exits
- [ ] Same with `useSystemPrompt` on: is the system dialog visible above the overlay?
- [ ] A wrong finger shows the backoff message, then Touch ID re-arms
- [ ] Trackpad hold for 3 s exits; quick taps and clicks while wiping don't
- [ ] Timer exits on its own
- [ ] Keyboard fully blocked: letters, media and brightness keys, Fn/Globe, ⌘Tab, ⌘⌥Esc, ⌃⌘Q, Spotlight, dictation
- [ ] Trackpad gestures blocked: Mission Control, App Exposé, swipe between Spaces, pinch, Notification Center
- [ ] Caps Lock state is the same after exit as before
- [ ] Pressing the power button: session ends cleanly and input works after waking
- [ ] Plug in or unplug a display mid-session: every screen stays covered
- [ ] Display doesn't dim during a long session
- [ ] With three-finger drag or drag lock turned on (Accessibility › Pointer Control), wiping the trackpad may hold a "click" down and trigger the hold exit, so check this
- [ ] Lid closed with an external display: card says Touch ID is unavailable, fallbacks still work

Known gaps: no global shortcut, no settings UI, no onboarding screen yet. Touch Bar Macs: the Touch Bar isn't blocked.
