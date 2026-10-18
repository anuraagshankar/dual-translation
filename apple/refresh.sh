#!/bin/bash
# Keeps the app alive on a free Apple account, whose signing profiles expire after 7 days:
# re-signs with fresh profiles and installs over Wi-Fi. launchd runs this hourly
# (see com.anuraagshankar.dualtranslator.refresh.plist); it does nothing until a refresh is due
# and the iPhone is reachable, so the Mac and phone only need to overlap occasionally.
#
#   apple/refresh.sh            hourly check
#   FORCE=1 apple/refresh.sh    refresh now (still needs the phone reachable)
set -uo pipefail

export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer # xcode-select points at CommandLineTools

DEVICE=${DEVICE:-00008030-000D289E1493402E}
PROJECT="$(cd "$(dirname "$0")" && pwd)/DualTranslator/DualTranslator.xcodeproj"
STATE_DIR="$HOME/Library/Application Support/DualTranslatorRefresh"
STATE="$STATE_DIR/expiry" # epoch seconds when the installed build stops working
APP="$STATE_DIR/build/Build/Products/Debug-iphoneos/DualTranslator.app"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
REFRESH_DAYS=5 # refresh once this many days or fewer are left
WARN_DAYS=2    # notify if still not refreshed this close to expiry
DAY=86400

log() { echo "$(date '+%F %T') $*"; }
notify() { osascript -e "display notification \"$1\" with title \"Translator\""; }
to_epoch() { date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s; }
profile_expiry() { to_epoch "$(security cms -D -i "$1" 2>/dev/null | plutil -extract ExpirationDate raw -o - -)"; }

# Earliest expiry of the app's and the widget's profiles in the last build, or 0.
built_expiry() {
    local a w
    a=$(profile_expiry "$APP/embedded.mobileprovision" 2>/dev/null) || { echo 0; return; }
    w=$(profile_expiry "$APP/PlugIns/DualTranslatorWidgetExtension.appex/embedded.mobileprovision" 2>/dev/null) || { echo 0; return; }
    echo $((a < w ? a : w))
}

build() {
    xcodebuild -project "$PROJECT" -scheme DualTranslator -configuration Debug \
        -destination 'generic/platform=iOS' -derivedDataPath "$STATE_DIR/build" \
        -allowProvisioningUpdates build >"$STATE_DIR/last-build.log" 2>&1
}

mkdir -p "$STATE_DIR"
now=$(date +%s)
installed=$(cat "$STATE" 2>/dev/null || echo 0)
left=$((installed - now))
[[ -z ${FORCE:-} ]] && ((left > REFRESH_DAYS * DAY)) && exit 0

reason=""
refresh() {
    if ! xcrun devicectl list devices 2>/dev/null | grep "$DEVICE" | grep -qE '[[:space:]](connected|available)'; then
        reason="iPhone isn't on the same Wi-Fi as the Mac."
        return 1
    fi

    # Reuse a build that was signed but never installed (e.g. the install failed last hour).
    local built
    built=$(built_expiry)
    if [[ -n ${FORCE:-} ]] || ((built - now <= REFRESH_DAYS * DAY)); then
        log "Signing with fresh profiles"
        # Xcode reuses cached profiles while they're valid; removing them makes Apple issue new 7-day ones.
        local backup
        backup=$(mktemp -d)
        mv "$PROFILES"/*.mobileprovision "$backup"/ 2>/dev/null
        # Retry once: if the Xcode app is open it fetches profiles at the same time, and the first
        # build can end up pointing at one the other request already replaced.
        if ! build && ! build; then
            mv -n "$backup"/*.mobileprovision "$PROFILES"/ 2>/dev/null
            reason="Build failed: check Xcode → Settings → Accounts. Log: $STATE_DIR/last-build.log"
            return 1
        fi
        built=$(built_expiry)
        if ((built - now < 6 * DAY)); then
            reason="Apple didn't issue fresh profiles (new build expires $(date -r "$built" '+%b %-d %H:%M'))."
            return 1
        fi
    fi

    if ! xcrun devicectl device install app --device "$DEVICE" "$APP" >/dev/null 2>&1; then
        reason="Install failed: unlock the iPhone."
        return 1
    fi
    echo "$built" >"$STATE"
    log "Installed; works until $(date -r "$built" '+%F %T')"
}

refresh && exit 0
log "Not refreshed: $reason"
# No state yet means no install has been recorded, not that the app expired.
if ((installed > 0 && left < WARN_DAYS * DAY)) && [[ -z $(find "$STATE_DIR/warned" -mmin -720 2>/dev/null) ]]; then
    if ((left > 0)); then
        notify "Expires $(date -r "$installed" '+%a %-d %b %H:%M'). $reason"
    else
        notify "Expired. $reason"
    fi
    touch "$STATE_DIR/warned"
fi
exit 1
