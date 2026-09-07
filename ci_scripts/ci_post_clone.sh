#!/bin/sh

#  ci_post_clone.sh
#  Xcode Cloud post-clone step.
#
#  WineTrail keeps DATADOG_CLIENT_TOKEN out of git via Secrets.xcconfig (see .gitignore).
#  Xcode Cloud clones only what is committed, so this script reconstructs it from an
#  Xcode Cloud environment variable before the build runs. Set this in the workflow
#  (App Store Connect > Xcode Cloud > your workflow > Environment > Environment Variables),
#  marking it Secret:
#
#    DATADOG_CLIENT_TOKEN - the Datadog client token (plain string)
#
#  (GoogleService-Info.plist is committed to the repo, so it needs no handling here.)
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
