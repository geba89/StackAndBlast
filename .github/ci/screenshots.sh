#!/bin/bash
# Launch the Debug build in several simulators, straight into a few screens
# (SCREENSHOT_SCENARIO, see ContentView), and print each screen as a text map.
#
# Usage: .github/ci/screenshots.sh path/to/StackAndBlast.app python-with-pillow
set -euo pipefail

APP="$1"
PYTHON="$2"
BUNDLE_ID="com.piotrgebski.StackAndBlast"
SCENARIOS="menu tutorial classic"

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
    UDID="$(udid_for "$NAME")"
    if [ -z "$UDID" ]; then
        echo "::warning::No simulator matching '$NAME' — skipped"
        continue
    fi

    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b > /dev/null
    xcrun simctl install "$UDID" "$APP"

    for SCENARIO in $SCENARIOS; do
        SIMCTL_CHILD_SCREENSHOT_SCENARIO="$SCENARIO" \
            xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" > /dev/null
        sleep 8 # let the UI settle (first launch includes Firebase/SpriteKit start-up)
        xcrun simctl io "$UDID" screenshot --type=png "/tmp/shot.png" > /dev/null 2>&1
        "$PYTHON" .github/ci/ascii_screenshot.py /tmp/shot.png "$COLUMNS" "$NAME — $SCENARIO"
    done

    xcrun simctl shutdown "$UDID" || true
done
