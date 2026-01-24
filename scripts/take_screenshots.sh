#!/bin/bash
# Screenshot Helper Script for App Store Submission
# This script opens each required simulator device size

set -e

PROJECT_PATH="/Users/gdemay/Documents/Saas/Online-now"
APP_SCHEME="OnlineNow"
SCREENSHOT_DIR="$HOME/Desktop/OnlineNow-Screenshots"

# Create screenshot directory
mkdir -p "$SCREENSHOT_DIR"

echo "📱 App Store Screenshot Helper"
echo "================================"
echo ""
echo "This script will:"
echo "1. Launch each required device simulator"
echo "2. Build and run the app"
echo "3. Wait for you to take screenshots (⌘S)"
echo ""
echo "Screenshots will be saved to: $SCREENSHOT_DIR"
echo ""

# Device configurations: NAME|DEVICE_ID_PATTERN|RESOLUTION
DEVICES=(
    "iPhone 16 Pro Max|iPhone 16 Pro Max|1320x2868"
    "iPhone 16 Plus|iPhone 16 Plus|1284x2778"
    "iPad Pro 13-inch|iPad Pro 13|2064x2752"
)

for device_config in "${DEVICES[@]}"; do
    IFS='|' read -r name pattern resolution <<< "$device_config"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 $name ($resolution)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Find device UDID
    UDID=$(xcrun simctl list devices available | grep "$pattern" | head -1 | grep -E -o -i "([0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12})")

    if [ -z "$UDID" ]; then
        echo "❌ Device not found: $name"
        echo "   Available devices:"
        xcrun simctl list devices available | grep "iPhone\|iPad" | head -5
        continue
    fi

    echo "✅ Found device: $UDID"

    # Boot simulator if not already booted
    echo "🔄 Booting simulator..."
    xcrun simctl boot "$UDID" 2>/dev/null || true

    # Open simulator app
    open -a Simulator --args -CurrentDeviceUDID "$UDID"

    # Wait for simulator to fully boot
    echo "⏳ Waiting for simulator to boot..."
    sleep 3

    # Build and run
    echo "🔨 Building and running app..."
    xcodebuild -project "$PROJECT_PATH/OnlineNow.xcodeproj" \
        -scheme "$APP_SCHEME" \
        -destination "platform=iOS Simulator,id=$UDID" \
        -configuration Release \
        build \
        2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" || true

    # Install and launch the app
    xcrun simctl install "$UDID" "$HOME/Library/Developer/Xcode/DerivedData/OnlineNow-"*/Build/Products/Release-iphonesimulator/OnlineNow.app 2>/dev/null || true
    xcrun simctl launch "$UDID" com.gdemay.onlinenow 2>/dev/null || true

    echo ""
    echo "✅ App launched on $name"
    echo ""
    echo "📸 PREVIEW MODE (for simulating offline/states):"
    echo "   • Triple-tap the screen to enter Preview Mode"
    echo "   • Tap to cycle states: Online → Offline → Limited → Checking → Speed Test"
    echo "   • Triple-tap again to exit Preview Mode"
    echo ""
    echo "📸 TAKE SCREENSHOTS:"
    echo "   1. Press ⌘S in Simulator to save screenshot"
    echo "   2. Screenshot saved to Desktop"
    echo "   3. Take screenshots for each state:"
    echo "      - Online (green) - default or Preview Mode"
    echo "      - Offline (red) - use Preview Mode"
    echo "      - Limited connectivity (orange) - use Preview Mode"
    echo "      - Speed test in progress - use Preview Mode"
    echo "      - History view (tap clock icon)"
    echo ""
    echo "Move screenshots to: $SCREENSHOT_DIR/$name/"
    mkdir -p "$SCREENSHOT_DIR/$name"
    echo ""

    read -p "Press ENTER when done with $name screenshots..."
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All simulators launched!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Organize your screenshots:"
echo "   Move Desktop screenshots to: $SCREENSHOT_DIR"
echo ""
echo "📏 Required sizes:"
echo "   • iPhone 16 Pro Max: 1320 x 2868"
echo "   • iPhone 16 Plus: 1290 x 2796"
echo "   • iPad Pro 13\": 2064 x 2752"
echo ""
echo "✨ Ready for App Store Connect upload!"
