#!/bin/sh
#
# Xcode Cloud runs this automatically right after cloning the repository,
# before resolving packages and building.
#
# GoogleService-Info.plist (Firebase config) is not stored in git, but the app
# needs it. Give it to Xcode Cloud as a SECRET environment variable:
#
#   1. On your Mac:  base64 -i GoogleService-Info.plist | pbcopy
#   2. App Store Connect → your app → Xcode Cloud → Manage Workflows → (workflow)
#      → Environment → Environment Variables → add
#      GOOGLE_SERVICE_INFO_PLIST_BASE64, paste the value, tick "Secret".

set -e

PLIST_PATH="$CI_PRIMARY_REPOSITORY_PATH/StackAndBlast/GoogleService-Info.plist"

if [ -z "$GOOGLE_SERVICE_INFO_PLIST_BASE64" ]; then
    echo "error: the GOOGLE_SERVICE_INFO_PLIST_BASE64 environment variable is not set."
    echo "Add it to the Xcode Cloud workflow as described at the top of ci_scripts/ci_post_clone.sh."
    exit 1
fi

echo "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$PLIST_PATH"
echo "Wrote $PLIST_PATH"
