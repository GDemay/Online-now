#!/bin/bash
# Simple script to verify screenshot dimensions

SCREENSHOT_DIR="$HOME/Desktop/OnlineNow-Screenshots"

echo "📐 Screenshot Dimension Checker"
echo "================================"
echo ""

if [ ! -d "$SCREENSHOT_DIR" ]; then
    echo "❌ Screenshot directory not found: $SCREENSHOT_DIR"
    echo "💡 Looking for screenshots on Desktop..."
    SCREENSHOT_DIR="$HOME/Desktop"
fi

echo "📁 Checking: $SCREENSHOT_DIR"
echo ""

# Required dimensions
declare -A REQUIRED_SIZES=(
    ["1320x2868"]="iPhone 16 Pro Max (6.9\")"
    ["1290x2796"]="iPhone 15 Pro Max (6.7\")"
    ["1284x2778"]="iPhone 14 Plus (6.5\")"
    ["2048x2732"]="iPad Pro 12.9\""
)

# Find all PNG files
found_screenshots=0

for img in "$SCREENSHOT_DIR"/*.png "$SCREENSHOT_DIR"/**/*.png; do
    if [ -f "$img" ]; then
        filename=$(basename "$img")

        # Get dimensions using sips
        dimensions=$(sips -g pixelWidth -g pixelHeight "$img" 2>/dev/null | awk '/pixel/ {printf "%sx%s", $2, $4}' | tr '\n' 'x' | sed 's/x$//')

        if [ -n "$dimensions" ]; then
            found_screenshots=$((found_screenshots + 1))

            # Check if dimensions match required sizes
            match=""
            for size in "${!REQUIRED_SIZES[@]}"; do
                if [ "$dimensions" == "$size" ]; then
                    match="✅ ${REQUIRED_SIZES[$size]}"
                    break
                fi
            done

            if [ -z "$match" ]; then
                match="⚠️  Custom size (not App Store requirement)"
            fi

            echo "📱 $filename"
            echo "   Size: $dimensions - $match"
            echo ""
        fi
    fi
done

if [ $found_screenshots -eq 0 ]; then
    echo "❌ No screenshots found in $SCREENSHOT_DIR"
    echo ""
    echo "💡 Tips:"
    echo "   1. Run the app in Simulator"
    echo "   2. Press ⌘S to take screenshots"
    echo "   3. Screenshots save to Desktop by default"
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Found $found_screenshots screenshot(s)"
    echo ""
    echo "📋 App Store Requirements:"
    for size in "${!REQUIRED_SIZES[@]}"; do
        echo "   • $size - ${REQUIRED_SIZES[$size]}"
    done
fi
