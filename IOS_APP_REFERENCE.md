# Personal iPhone App + Widget: Reference

What was actually done to get the Dual Translator app and widget onto an iPhone SE 2020 (iOS 18.4) with a **free** Apple account, and to keep it working without paying for the Apple Developer Program. Verified 2026-10-18.

## Key facts
- A free Apple account (Xcode "Personal Team") can build and install the app plus its WidgetKit extension on your own iPhone.
- Its signing profiles expire **7 days** after they are issued; after that the app won't open and the widget stops working until it is re-signed and reinstalled.
- **Rebuilding does not reset the 7 days.** Xcode keeps reusing its cached profile while it is still valid. To get a fresh 7-day profile, delete the cached profiles first (see [Renewing the 7 days](#renewing-the-7-days)).
- Installing works **over Wi-Fi** and **while the phone is locked**. Only opening the app remotely needs it unlocked.
- Reinstalling keeps the app's data (e.g. the last-used language), as long as the bundle IDs and team stay the same.
- Paid membership (about US$99/year) gives longer-lived profiles. Not needed for now.

## One-time setup (what was done)

### Mac and Xcode
1. Install Xcode. In its **Components** screen only the **iOS** platform is needed (about 16 GB; it includes the Simulator). macOS is built in; watchOS, tvOS and visionOS were skipped.
2. **Xcode → Settings → Accounts → +** → sign in with the Apple ID. This creates the "Personal Team".
3. `xcode-select` still points at the standalone Command Line Tools, so terminal builds need `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` in front of them. Switching it once with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` would also work, but wasn't needed.

### Project
4. **File → New → Project → Choose Template… → iOS tab → App.** The quick list (App, Command Line Tool, Package, Playground) doesn't show the platforms; "Choose Template…" does.
   - Product Name `DualTranslator`, Team = Personal Team, Organization Identifier `com.anuraagshankar` (bundle ID `com.anuraagshankar.DualTranslator`).
   - Interface SwiftUI, Language Swift, Testing System None, Storage None.
   - Saved in `apple/`, with **"Create Git repository" unchecked** (the repo already exists).
5. **File → New → Target → iOS → Widget Extension**, named `DualTranslatorWidget`, with **Live Activity, Control and Configuration App Intent all unchecked**. Click Activate when asked.
6. Fix the build settings Xcode got wrong for this phone (done by editing `project.pbxproj`, for both targets):
   - `IPHONEOS_DEPLOYMENT_TARGET` 27.0 → **18.0**. Xcode defaults to the newest iOS, which shows the phone as "OS version lower than deployment target".
   - `TARGETED_DEVICE_FAMILY` → **1** (iPhone only).
7. App-specific settings:
   - `DualTranslator-Info.plist` (outside the synced source folder) registers the `dualtranslator://` URL scheme that the widget links use. The app target points at it with `INFOPLIST_FILE`.
   - `INFOPLIST_KEY_CFBundleDisplayName = Translator`, the name shown under the icon and on the widget.
   - The DeepL key lives in `apple/DualTranslator/DualTranslator/Secrets.swift`, which is **git-ignored**. Copy it from `web/.env` on a new machine: `let deepLKey = "..."`.
   - App icon: three 1024×1024 PNGs (default, dark, tinted) in `AppIcon.appiconset`.
8. Xcode uses folder-synced groups, so any Swift file dropped into `DualTranslator/` or `DualTranslatorWidget/` is compiled automatically. If Xcode shows "Cannot find … in scope" right after files are added from outside, it's stale: press **⌘B**.

### iPhone
9. Connect by USB, tap **Trust** on the phone, then enable **Settings → Privacy & Security → Developer Mode** (restarts the phone; the option only appears after Xcode has seen the phone).
10. In Xcode's top bar pick scheme **DualTranslator** (not the widget extension) and device **Anuraag's iPhone**, then **▶**.
11. The first time, Xcode said "Build Succeeded" but nothing opened. Launching from the terminal showed the real reason: the developer profile wasn't trusted. Fix on the phone: **Settings → General → VPN & Device Management → (your Apple ID) → Trust**. Only needed once per Apple ID.
12. Add the widget: long-press the Home Screen → **+** → "Translator" → medium size.
13. Optional: **Settings → Apps → Translator → Paste from Other Apps → Allow** stops the "Allow Paste?" prompt when using the widget's paste icon.
14. Unplug the cable. The phone stays reachable over Wi-Fi when on the same network as the Mac (`xcrun devicectl list devices` shows it as `connected`, transport `localNetwork`). If it ever drops off, plugging the cable in once usually brings it back.

## Terminal commands
Device ID of the iPhone: `00008030-000D289E1493402E`.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Is the phone reachable?
xcrun devicectl list devices

# Build and sign (Xcode's normal build folder; ▶ in Xcode does the same)
xcodebuild -project apple/DualTranslator/DualTranslator.xcodeproj -scheme DualTranslator \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates build

# Install over Wi-Fi (the widget is inside the app, no separate install)
xcrun devicectl device install app --device 00008030-000D289E1493402E \
  ~/Library/Developer/Xcode/DerivedData/DualTranslator-*/Build/Products/Debug-iphoneos/DualTranslator.app

# Open it (fails if the phone is locked)
xcrun devicectl device process launch --device 00008030-000D289E1493402E --terminate-existing com.anuraagshankar.DualTranslator

# When does a build stop working? (app and widget each have a profile)
security cms -D -i <path>/DualTranslator.app/embedded.mobileprovision | plutil -extract ExpirationDate raw -o - -
```

## Renewing the 7 days
1. Move the cached profiles out of `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` (one for the app, one for the widget).
2. Build with `-allowProvisioningUpdates`. Apple issues new profiles valid for 7 days from now.
3. Check `ExpirationDate` in the new build (above) instead of assuming it moved.
4. Install over Wi-Fi.

If the Xcode app is open during step 2, it fetches profiles at the same time and the first build can fail with *"Build input file cannot be found: …/Provisioning Profiles/<id>.mobileprovision"*. Building a second time, without deleting anything, succeeds.

## Automation (installed)
`apple/refresh.sh` does the renewal above. A LaunchAgent runs it **every hour** and at login. Most runs do nothing; it only acts when a refresh is due and the phone is reachable, so the Mac and phone only need to be on the same Wi-Fi now and then.

| Days left on the installed app | Phone reachable? | What happens |
|---|---|---|
| More than 5 | n/a | Exits immediately (about 10 ms) |
| 5 or fewer | No | Logs it, tries again next hour |
| 5 or fewer | Yes | Fresh profiles → build → check expiry → install (about 15 s) |
| 2 or fewer, still not refreshed | No | macOS notification with the reason, at most every 12 hours |

Files:
- Script: `apple/refresh.sh`. `FORCE=1 apple/refresh.sh` refreshes now (still needs the phone reachable).
- Schedule: `apple/com.anuraagshankar.dualtranslator.refresh.plist`, copied to `~/Library/LaunchAgents/`. It runs as a low-priority background job.
- State: `~/Library/Application Support/DualTranslatorRefresh/`:
  - `expiry`: when the installed build stops working, in epoch seconds. Read it with `date -r $(cat expiry)`.
  - `build/`: the script's own build folder.
  - `last-build.log`: output of the last build.
- Log: `~/Library/Logs/DualTranslatorRefresh.log`.

Manage it:
```bash
# Status (last exit code 0 = fine)
launchctl print gui/$(id -u)/com.anuraagshankar.dualtranslator.refresh | grep -E "runs|last exit"
# Stop
launchctl bootout gui/$(id -u)/com.anuraagshankar.dualtranslator.refresh
# Start again (after editing the plist, copy it to ~/Library/LaunchAgents first)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.anuraagshankar.dualtranslator.refresh.plist
```

It depends on:
- The Mac being on with you logged in. Signing needs the login keychain and Xcode's Apple ID session. Missed hours run when the Mac wakes.
- The phone being on the same Wi-Fi at some point in the 5-day window. Fallback: plug in the cable or press ▶ in Xcode.
- Xcode staying signed in to the Apple ID. If the session expires, builds fail and the notification says to check **Xcode → Settings → Accounts**.

## Caveats
- If you press ▶ in Xcode, the phone gets whatever profile Xcode has cached. The script's `expiry` file doesn't know about that, so it may refresh earlier than strictly needed. That's harmless.
- Whether Apple rate-limits frequent profile requests on free accounts is unknown. This setup asks for about one every 2–3 days.
- Some capabilities aren't available to free Personal Teams. None are used by this app.
- A web app (PWA) on the Home Screen is free and never expires, but it can't provide a real WidgetKit widget.
