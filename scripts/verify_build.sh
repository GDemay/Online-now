#!/bin/bash
# Run actual checks and preserve their exit status and diagnostic output.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then
    echo "iOS verification requires macOS with Xcode. Use the iOS verification GitHub workflow."
    exit 2
fi
if [[ -z "${ONLINE_NOW_DESTINATION:-}" ]]; then
    echo "Set ONLINE_NOW_DESTINATION to platform=iOS Simulator,id=<simulator UUID>."
    exit 2
fi
xcodebuild test -project OnlineNow.xcodeproj -scheme OnlineNow \
    -destination "$ONLINE_NOW_DESTINATION" CODE_SIGNING_ALLOWED=NO
swift test --skip SpeedTestValidationTests
