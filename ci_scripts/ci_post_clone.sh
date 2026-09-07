#!/bin/sh

#  ci_post_clone.sh
#  Xcode Cloud post-clone step.
#
#  WineTrail keeps two secrets OUT of git (see .gitignore): Secrets.xcconfig
#  (which supplies DATADOG_CLIENT_TOKEN) and GoogleService-Info.plist. Xcode Cloud
#  clones only what is committed, so this script reconstructs both from Xcode Cloud
#  environment variables before the build runs. Set these in the workflow
#  (App Store Connect > Xcode Cloud > your workflow > Environment > Environment Variables),
#  marking them Secret:
#
#    DATADOG_CLIENT_TOKEN        - the Datadog client token (plain string)
#    GOOGLE_SERVICE_INFO_PLIST_BASE64 - `base64 < GoogleService-Info.plist` (single line)
#
#  Xcode Cloud runs this from the ci_scripts/ directory; the repo root is its parent.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Secrets.xcconfig (DATADOG_CLIENT_TOKEN) -------------------------------------
SECRETS_PATH="$REPO_ROOT/WineTrail/Resources/Secrets.xcconfig"
if [ -n "$DATADOG_CLIENT_TOKEN" ]; then
    mkdir -p "$(dirname "$SECRETS_PATH")"
    printf 'DATADOG_CLIENT_TOKEN = %s\n' "$DATADOG_CLIENT_TOKEN" > "$SECRETS_PATH"
    echo "ci_post_clone: wrote Secrets.xcconfig"
else
    echo "ci_post_clone: WARNING - DATADOG_CLIENT_TOKEN not set; Secrets.xcconfig not written"
fi

# --- GoogleService-Info.plist (Firebase) ----------------------------------------
GOOGLE_PLIST_PATH="$REPO_ROOT/WineTrail/Supporting/GoogleService-Info.plist"
if [ -n "$GOOGLE_SERVICE_INFO_PLIST_BASE64" ]; then
    mkdir -p "$(dirname "$GOOGLE_PLIST_PATH")"
    echo "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$GOOGLE_PLIST_PATH"
    echo "ci_post_clone: wrote GoogleService-Info.plist"
else
    echo "ci_post_clone: WARNING - GOOGLE_SERVICE_INFO_PLIST_BASE64 not set; GoogleService-Info.plist not written"
fi
