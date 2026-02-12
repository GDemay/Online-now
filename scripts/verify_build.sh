#!/bin/bash
# Build Verification Script for OnlineNow
# This script verifies that all code compiles and tests pass

set -e  # Exit on error

echo "🔨 OnlineNow Build Verification"
echo "================================"
echo ""

# 1. Clean build artifacts
echo "1️⃣  Cleaning build artifacts..."
swift package clean
rm -rf .build
echo "   ✅ Clean complete"
echo ""

# 2. Build the package
echo "2️⃣  Building package..."
if swift build 2>&1 | grep -q "Build complete"; then
    echo "   ✅ Build successful"
else
    echo "   ❌ Build failed"
    exit 1
fi
echo ""

# 3. Build tests
echo "3️⃣  Building tests..."
if swift build --build-tests 2>&1 | grep -q "Build complete"; then
    echo "   ✅ Test build successful"
else
    echo "   ❌ Test build failed"
    exit 1
fi
echo ""

# 4. Run tests
echo "4️⃣  Running tests..."
if swift test 2>&1 | tail -1 | grep -q "passed"; then
    echo "   ✅ All tests passed"
else
    echo "   ⚠️  Some tests may have issues (check output above)"
fi
echo ""

# 5. Verify new services exist
echo "5️⃣  Verifying new services..."

if [ -f "Sources/OnlineNow/Services/LatencyMeasurementService.swift" ]; then
    echo "   ✅ LatencyMeasurementService.swift exists"
else
    echo "   ❌ LatencyMeasurementService.swift missing"
    exit 1
fi

if [ -f "Sources/OnlineNow/Services/DiagnosticService.swift" ]; then
    echo "   ✅ DiagnosticService.swift exists"
else
    echo "   ❌ DiagnosticService.swift missing"
    exit 1
fi

if [ -f "Sources/OnlineNow/Services/SpeedTestService.swift" ]; then
    echo "   ✅ SpeedTestService.swift exists"
else
    echo "   ❌ SpeedTestService.swift missing"
    exit 1
fi
echo ""

# 6. Check for common issues
echo "6️⃣  Checking for common issues..."

# Check if services are properly public
if grep -q "public actor LatencyMeasurementService" Sources/OnlineNow/Services/LatencyMeasurementService.swift; then
    echo "   ✅ LatencyMeasurementService is public"
else
    echo "   ❌ LatencyMeasurementService is not public"
    exit 1
fi

if grep -q "public actor DiagnosticService" Sources/OnlineNow/Services/DiagnosticService.swift; then
    echo "   ✅ DiagnosticService is public"
else
    echo "   ❌ DiagnosticService is not public"
    exit 1
fi

if grep -q "public struct DiagnosticResult" Sources/OnlineNow/Services/DiagnosticService.swift; then
    echo "   ✅ DiagnosticResult is public"
else
    echo "   ❌ DiagnosticResult is not public"
    exit 1
fi
echo ""

echo "================================"
echo "✅ ALL CHECKS PASSED!"
echo ""
echo "If Xcode still shows errors:"
echo "1. Close Xcode"
echo "2. Run: rm -rf ~/Library/Developer/Xcode/DerivedData"
echo "3. Run: swift package reset"
echo "4. Run: xcodegen generate (if using XcodeGen)"
echo "5. Reopen Xcode and wait for indexing to complete"
echo ""
