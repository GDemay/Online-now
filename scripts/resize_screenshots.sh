#!/bin/bash

# Screenshot Resizer for App Store Connect
# Resizes simulator screenshots to match App Store requirements

set -e

SOURCE_DIR="$HOME/Desktop"
OUTPUT_DIR="$HOME/Desktop/AppStore-Ready-Screenshots"

# Create output directories
mkdir -p "$OUTPUT_DIR/iPhone-6.5"
mkdir -p "$OUTPUT_DIR/iPad-Pro-12.9"

echo "📸 App Store Screenshot Resizer"
echo "================================"
echo ""
echo "Source: $SOURCE_DIR"
echo "Output: $OUTPUT_DIR"
echo ""

# Counter for processed files
iphone_count=0
ipad_count=0

# Process iPhone 16 Pro Max screenshots (1320x2868 → 1284x2778)
echo "📱 Processing iPhone screenshots..."
for file in "$SOURCE_DIR"/Simulator\ Screenshot\ -\ iPhone\ 16\ Pro\ Max\ -\ 2026-01-24*.png \
            "$SOURCE_DIR"/Simulator\ Screenshot\ -\ iPhone\ 16\ Plus\ -\ 2026-01-24*.png \
            "$SOURCE_DIR"/Simulator\ Screenshot\ -\ iPhone\ 17\ Pro\ -\ 2026-01-24*.png; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        output_file="$OUTPUT_DIR/iPhone-6.5/$(date +%s)-${filename// /_}"

        # Resize to 1284x2778 (6.5" display requirement)
        sips -z 2778 1284 "$file" --out "$output_file" > /dev/null 2>&1

        echo "  ✓ Resized: $filename"
        ((iphone_count++))
    fi
done

# Process iPad Pro screenshots (2064x2752 → 2048x2732)
echo ""
echo "📱 Processing iPad screenshots..."
for file in "$SOURCE_DIR"/Simulator\ Screenshot\ -\ iPad\ Pro\ 13-inch*.png; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        output_file="$OUTPUT_DIR/iPad-Pro-12.9/$(date +%s)-${filename// /_}"

        # Resize to 2048x2732 (iPad Pro 12.9" requirement)
        sips -z 2732 2048 "$file" --out "$output_file" > /dev/null 2>&1

        echo "  ✓ Resized: $filename"
        ((ipad_count++))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Processing Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Results:"
echo "   iPhone screenshots: $iphone_count files → 1284 × 2778px"
echo "   iPad screenshots:   $ipad_count files → 2048 × 2732px"
echo ""
echo "📁 Ready for upload:"
echo "   iPhone 6.5\": $OUTPUT_DIR/iPhone-6.5/"
echo "   iPad Pro:     $OUTPUT_DIR/iPad-Pro-12.9/"
echo ""
echo "🚀 Now upload these to App Store Connect!"
echo "   - iPhone 6.5\" Display: Use files from iPhone-6.5/"
echo "   - iPad Pro 12.9\" Display: Use files from iPad-Pro-12.9/"
