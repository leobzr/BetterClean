# BetterClean

Clean your MacBook's keyboard, trackpad and screen without clicking or typing anything by accident. BetterClean turns the screen black (so smudges are easy to see) and ignores the keyboard and trackpad until you unlock it with your fingerprint.

**You need:** a Mac with an Apple chip (M1 or newer) running macOS 13 Ventura or later. Touch ID is recommended but not required.

## Install

1. Unzip `BetterClean.zip` and drag **BetterClean** into your **Applications** folder.
2. Open it. macOS will warn that it can't verify the app, because it isn't from the App Store or a registered developer. Click **Done**.
3. Open **System Settings › Privacy & Security**, scroll down and click **Open Anyway** next to the BetterClean message. Confirm with your password or Touch ID.
4. In the BetterClean window, click **Open Accessibility Settings** and turn **BetterClean** on. This lets it block the keyboard and trackpad while you clean.

The window shows a green **Accessibility access granted** line when you're ready.

## Clean

1. Choose how long until it unlocks by itself (20 seconds by default, up to 15 minutes).
2. Click **Start Cleaning Mode**. The screen goes black and the keyboard and trackpad stop working.
3. Wipe away.

You can also start from the ✦ icon in the menu bar at the top of the screen.

## Exit

Any of these:

- **Touch ID:** rest a registered finger **lightly** on the Touch ID button. Don't press it: it's also the power button, and pressing it simply ends cleaning mode.
- **Trackpad:** press and hold the trackpad for 3 seconds.
- **Wait:** it unlocks by itself when the timer runs out.

## Good to know

- Use a dry or slightly damp microfiber cloth. Never spray liquid directly on the Mac. For anything wetter, Apple recommends shutting the Mac down first.
- If Touch ID doesn't recognize your finger, it pauses for the rest of that session so macOS doesn't lock it and ask for your password. Use the trackpad hold instead.
- With an external monitor connected, Touch ID sometimes doesn't respond. Use the trackpad hold.

## Troubleshooting

- **Nothing happens when I open it:** it lives in the menu bar (✦ icon). If you have many menu bar icons it can hide behind the notch. Open BetterClean again from Applications to bring its window back.
- **"Start Cleaning Mode" is greyed out:** turn on BetterClean in System Settings › Privacy & Security › Accessibility. If it's already on, remove it with **−**, add it again and reopen the app.
- **"Can't start cleaning mode… Secure Keyboard Entry":** another app is protecting a password field. Close the password field (or quit the app holding it, often a terminal or password manager) and try again.
- **Something went wrong and I can't get out:** wait for the timer. As a last resort, hold the power button for about 10 seconds to shut down.

## Uninstall

Quit BetterClean from its menu bar icon, delete it from Applications, and remove it from System Settings › Privacy & Security › Accessibility.

---

# For developers

Menu bar app that blacks out every display and blocks keyboard and trackpad input so a MacBook can be wiped. Exit with Touch ID, by holding the trackpad down for 3 s, or by waiting for the timer.

### Build and run

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

**Make a zip to share** (what the user guide above expects):

```sh
scripts/build-app.sh release
ditto -c -k --keepParent build/BetterClean.app BetterClean.zip
```

Logs: `log stream --predicate 'subsystem == "local.betterclean.prototype"'`

### Layout

| Component | File | Role |
|---|---|---|
| `CleaningSession` | `Sources/BetterClean/CleaningSession.swift` | Starts and ends a session; ending restores input first |
| `InputBlocker` | `Sources/BetterClean/InputBlocker.swift` | Event tap that swallows input; lets everything through once past its deadline |
| `OverlayController` | `Sources/BetterClean/OverlayController.swift` | Black windows per display, status card, embedded Touch ID view |
| `BiometricUnlocker` | `Sources/BetterClean/BiometricUnlocker.swift` | Biometrics-only prompt; pauses for the session after one failed round |
| `SystemGuards` | `Sources/BetterClean/SystemGuards.swift` | Accessibility check, Secure Input check, display-sleep assertion, Caps Lock restore |
| `CleaningCore` | `Sources/CleaningCore/` | Pure, tested logic: long-press detector, retry policy, session clock, timer options |

Rule: any change to the tap or exit logic must keep **both** fallbacks (timer and trackpad hold).

### Prototype test checklist

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
