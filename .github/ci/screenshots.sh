#!/bin/bash
# Launch the Debug build in several simulators, straight into a few screens
# (SCREENSHOT_SCENARIO, see ScreenshotScenario in ContentView.swift), save a
# screenshot of each, and print each screen as a text map in the log.
#
# Usage: .github/ci/screenshots.sh path/to/StackAndBlast.app python-with-pillow output-dir
# Output: output-dir/<device>-<scenario>.png (full size) and .jpg (small, for the repo)
set -euo pipefail

APP="$1"
PYTHON="$2"
OUT="$3"
BUNDLE_ID="com.piotrgebski.StackAndBlast"
SCENARIOS="menu missions tutorial classic board gameover"

mkdir -p "$OUT"

echo "Available simulators:"
xcrun simctl list devices available | grep -E "iPhone|iPad" || true

# Find a simulator's UDID by name prefix (runner images differ in what they ship)
udid_for() {
    xcrun simctl list devices available -j | "$PYTHON" -c '
import json, sys
prefix = sys.argv[1]
devices = [d for runtime in json.load(sys.stdin)["devices"].values() for d in runtime]
match = next((d for d in devices if d["name"] == prefix), None) or \
        next((d for d in devices if d["name"].startswith(prefix)), None)
print(match["udid"] if match else "")
' "$1"
}

# "Device name prefix:text columns" — iPad gets more columns (it's much wider)
for ENTRY in "iPhone SE:48" "iPhone 16 Pro:48" "iPad Pro 13-inch:64"; do
    NAME="${ENTRY%%:*}"
    COLUMNS="${ENTRY##*:}"
    # File name prefix: "iPad Pro 13-inch" → "ipad-pro-13-inch"
    SLUG="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    UDID="$(udid_for "$NAME")"
    if [ -z "$UDID" ]; then
        echo "::warning::No simulator matching '$NAME' — skipped"
        continue
    fi

    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b > /dev/null
    # Clean status bar (9:41, full battery), like App Store screenshots
    xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged \
        --batteryLevel 100 --wifiBars 3 --cellularBars 4 2>/dev/null || true
    xcrun simctl install "$UDID" "$APP"

    for SCENARIO in $SCENARIOS; do
        SHOT="$OUT/$SLUG-$SCENARIO.png"
        LOG="$OUT/$SLUG-$SCENARIO" # + .stdout.txt / .stderr.txt: the app's console output
        MARKER="$(mktemp)" # crash reports newer than this belong to this launch

        SIMCTL_CHILD_SCREENSHOT_SCENARIO="$SCENARIO" \
            xcrun simctl launch --terminate-running-process \
            --stdout="$LOG.stdout.txt" --stderr="$LOG.stderr.txt" "$UDID" "$BUNDLE_ID" > /dev/null
        sleep 10 # let the UI settle (first launch includes Firebase/SpriteKit start-up)
        xcrun simctl io "$UDID" screenshot --type=png "$SHOT" > /dev/null 2>&1

        # Still running? A running app is listed by launchctl with its PID first.
        APP_LINE="$(xcrun simctl spawn "$UDID" launchctl list | grep -F "$BUNDLE_ID" || true)"
        if [[ ! "$APP_LINE" =~ ^[0-9]+ ]]; then
            echo "::error::The app is not running on $NAME ($SCENARIO) — it probably crashed"
            echo "--- launchctl: ${APP_LINE:-not listed}"
            echo "--- Last lines of its console output:"
            tail -n 40 "$LOG.stderr.txt" "$LOG.stdout.txt" 2>/dev/null || true
            find ~/Library/Logs/DiagnosticReports -name '*.ips' -newer "$MARKER" 2>/dev/null \
                | while read -r REPORT; do "$PYTHON" .github/ci/crash_summary.py "$REPORT"; done
        fi
        rm -f "$MARKER"

        "$PYTHON" .github/ci/ascii_screenshot.py "$SHOT" "$COLUMNS" "$NAME — $SCENARIO"
        # Small JPEG copy (longest side 1200px) — light enough to commit to the repo
        sips -s format jpeg -s formatOptions 70 -Z 1200 "$SHOT" --out "${SHOT%.png}.jpg" > /dev/null
    done

    xcrun simctl shutdown "$UDID" || true
done

ls -la "$OUT"
