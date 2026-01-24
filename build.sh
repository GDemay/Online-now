#!/bin/bash

# Build script for Online Now iOS app
# This script helps automate building and testing the app

set -e  # Exit on error

echo "🚀 Online Now Build Script"
echo "=========================="
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode is not installed or xcodebuild is not in PATH"
    exit 1
fi

echo "✅ Xcode found"

# Navigate to project directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Project settings
PROJECT="OnlineNow.xcodeproj"
SCHEME="OnlineNow"
DESTINATION="platform=iOS Simulator,name=iPhone 14,OS=latest"

echo "📦 Building Online Now..."
echo ""

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    > /dev/null 2>&1

echo "✅ Clean complete"

# Build the project
echo "🔨 Building project..."
xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -quiet

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "Next steps:"
    echo "  • Open in Xcode: open $PROJECT"
    echo "  • Run on simulator: Select Run (⌘R) in Xcode"
    echo "  • Run on device: Connect device and select as target"
    echo ""
    echo "📱 App is ready to run!"
else
    echo "❌ Build failed"
    exit 1
fi
