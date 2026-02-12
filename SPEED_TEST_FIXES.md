# Speed Test and Latency Fixes - Implementation Summary

## Overview
Fixed critical issues with speed test and latency measurements in the OnlineNow network monitoring library. The implementations now provide accurate, reliable measurements comparable to terminal-based tools like `ping` and `speedtest-cli`.

## Issues Fixed

### 1. Speed Test - Byte Counting Bug ✅
**Problem**: The original implementation iterated through downloaded bytes one at a time:
```swift
for try await _ in bytes {
    totalBytes += 1  // ❌ Counted individual bytes instead of receiving actual data
}
```

This was extremely inefficient and inaccurate because:
- It counted loop iterations, not actual bytes received
- Each iteration only accessed metadata, not the actual data transfer
- Download speed calculations were completely wrong

**Solution**: Changed to use `URLSession.data()` which downloads the entire file and returns the actual byte count:
```swift
let (data, response) = try await session.data(from: testURL)
let totalBytes = data.count  // ✅ Actual bytes downloaded
```

**Result**: Speed test now accurately measures download speed by timing actual data transfer.

---

### 2. Latency Measurement - HTTP vs TCP RTT ✅
**Problem**: The original "latency" measurement was actually HTTP response time, which includes:
- DNS lookup time
- TCP handshake time
- TLS handshake time
- Server processing time
- Actual network round-trip time (RTT)

This gave inflated latency values (100-300ms) compared to actual network latency.

**Solution**: Created `LatencyMeasurementService` that:
1. Measures true TCP RTT using `Network` framework's `NWConnection`
2. Times only the TCP SYN → SYN-ACK handshake (pure network latency)
3. Provides separate measurements for:
   - `rttMs`: True network latency (TCP)
   - `responseTimeMs`: Full HTTP response time (DNS + TCP + TLS + server)

**Typical Results**:
- TCP RTT: 15-50ms (actual network latency)
- HTTP Response: 50-150ms (includes overhead)
- Overhead: 35-100ms (DNS, TLS, server processing)

---

### 3. Backward Compatibility ✅
All changes maintain backward compatibility with deprecation warnings:

```swift
// Old property (deprecated)
@Published public private(set) var latencyMs: Double?

// New properties
@Published public private(set) var rttMs: Double?  // TCP RTT
@Published public private(set) var responseTimeMs: Double?  // HTTP timing
```

---

## New Features

### 1. LatencyMeasurementService
- Measures TCP RTT to common endpoints (Cloudflare DNS, Google DNS, etc.)
- Provides average latency across multiple samples
- Includes HTTP response time measurement for comparison
- Quality descriptions ("Excellent", "Good", "Fair", "Poor")

### 2. DiagnosticService
- Validates app measurements against system tools (macOS only)
- Runs system `ping` and compares with app's TCP RTT
- Provides detailed comparison reports
- Calculates percentage differences between measurements

### 3. Enhanced Data Models
Updated `ConnectivityCheck` model to store:
- `rttMs`: Network latency
- `responseTimeMs`: HTTP response time
- `measurementMethod`: Method used ("TCP", "HTTP", "ICMP")

---

## Testing & Validation

### Automated Tests
Created `SpeedTestValidationTests.swift` with tests for:
1. Speed test byte counting accuracy
2. Speed calculation formula verification
3. TCP latency measurement
4. HTTP vs TCP timing comparison
5. Diagnostic service validation

### Manual Testing with Terminal

#### Test Latency (ping)
```bash
# Test against Cloudflare DNS
ping -c 10 1.1.1.1

# Compare results:
# - App TCP RTT should be 5-15ms higher than ICMP ping
# - Both should be in same order of magnitude (e.g., both 15-50ms)
```

#### Test Speed (speedtest-cli)
```bash
# Install speedtest-cli (macOS)
brew install speedtest-cli

# Run speed test
speedtest-cli --simple

# Compare results:
# - App and speedtest-cli should be within 20% of each other
# - Note: Different servers may give different speeds
```

#### Test HTTP Timing (curl)
```bash
# Detailed HTTP timing
curl -w "@-" -o /dev/null -s "https://www.google.com" <<'EOF'
time_connect:     %{time_connect}s  (TCP handshake)
time_appconnect:  %{time_appconnect}s  (TLS handshake)
time_total:       %{time_total}s  (Full request)
EOF

# Compare:
# - time_connect (seconds) ≈ app's rttMs (milliseconds) / 1000
# - time_total (seconds) ≈ app's responseTimeMs (milliseconds) / 1000
```

### Run Diagnostic Mode (macOS Only)
```swift
// Enable diagnostic mode
viewModel.isDiagnosticMode = true

// Run validation
await viewModel.runDiagnostics()

// Check results
for result in viewModel.diagnosticResults {
    print(result.summary)
}
```

---

## Code Changes Summary

### Modified Files
1. **SpeedTestService.swift** - Fixed byte counting and speed calculation
2. **ReachabilityService.swift** - Renamed `latencyMs` → `responseTimeMs` with deprecation
3. **ConnectivityViewModel.swift** - Added RTT measurement and diagnostic support
4. **ConnectivityCheck.swift** - Added new measurement fields
5. **SharedTypes.swift** - (No changes needed, structure already good)

### New Files
1. **LatencyMeasurementService.swift** - TCP RTT measurement service
2. **DiagnosticService.swift** - Validation against system tools
3. **SpeedTestValidationTests.swift** - Comprehensive test suite

---

## Usage Examples

### Measure Network Latency
```swift
let latencyService = LatencyMeasurementService()

// Single measurement
let result = await latencyService.measureTCPLatency(to: .cloudflare)
print("Latency: \(result.formattedLatency)")  // e.g., "23 ms"
print("Quality: \(result.qualityDescription)")  // e.g., "Excellent"

// Average measurement
let avgResult = await latencyService.measureAverageLatency(samples: 3)
print("Average: \(avgResult.formattedLatency)")
```

### Validate Measurements
```swift
let diagnosticService = DiagnosticService()

// Validate latency against system ping (macOS only)
let validation = await diagnosticService.validateLatency(host: "1.1.1.1")
print(validation.summary)
// Output:
// ✅ Latency Test
// App: 25.0 ms (TCP)
// System: 22.3 ms (ICMP ping)
// Difference: 2.7 ms (12%)
```

### Access in ViewModel
```swift
let viewModel = ConnectivityViewModel()

// New measurements
print("Network RTT: \(viewModel.rttMs ?? 0) ms")
print("HTTP Response: \(viewModel.responseTimeMs ?? 0) ms")

// Legacy property (still works, deprecated)
print("Legacy latency: \(viewModel.latencyMs ?? 0) ms")
```

---

## Expected Measurement Ranges

### Latency (TCP RTT)
- **Excellent**: 0-20ms (LAN, nearby servers)
- **Very Good**: 20-50ms (Regional)
- **Good**: 50-100ms (Cross-country)
- **Fair**: 100-200ms (International)
- **Poor**: 200-500ms (Satellite, congested)
- **Very Poor**: 500ms+ (Severe issues)

### Speed (Download)
- **Excellent**: 50+ Mbps (Fiber, good broadband)
- **Good**: 25-50 Mbps (Standard broadband)
- **Fair**: 10-25 Mbps (Basic broadband)
- **Acceptable**: 5-10 Mbps (Slow broadband)
- **Poor**: <5 Mbps (Very slow connection)

---

## Platform Support

| Feature | iOS | macOS | watchOS |
|---------|-----|-------|---------|
| Speed Test | ✅ | ✅ | ✅ |
| TCP Latency | ✅ | ✅ | ✅ |
| HTTP Response Time | ✅ | ✅ | ✅ |
| System Ping Validation | ❌ | ✅ | ❌ |
| Diagnostic Reports | ❌ | ✅ | ❌ |

*System ping requires `Process` API which is only available on macOS*

---

## Known Differences from Terminal Tools

### TCP RTT vs ICMP Ping
- App uses TCP (port 443), ping uses ICMP
- TCP is typically 5-15ms slower due to additional handshake
- Both measure true network latency, just different protocols
- TCP better reflects real-world HTTPS connections

### Speed Test Endpoints
- App uses Cloudflare CDN: `speed.cloudflare.com`
- `speedtest-cli` uses Ookla network: `speedtest.net`
- Different servers may show different speeds
- Results within 20% are considered normal

---

## Performance

### Speed Test
- **Quick test**: 5MB download (~1-5 seconds)
- **Full test**: 10MB download (~2-10 seconds)
- **Data usage**: Actual bytes downloaded (5-10MB per test)

### Latency Test
- **Single measurement**: <100ms per endpoint
- **Average (3 samples)**: <300ms
- **Data usage**: Minimal (~1KB per test)

---

## Future Improvements

1. **Add upload speed test** - Currently only measures download
2. **Add ICMP ping on iOS** - Requires network extension or VPN profile
3. **Add jitter measurement** - Variation in latency over time
4. **Add packet loss detection** - Important for gaming/VoIP
5. **Add bandwidth throttling detection** - Detect ISP throttling
6. **Add geographic latency map** - Visual representation of latency to different regions

---

## Migration Guide

If you were using the old `latencyMs` property:

```swift
// Old code (still works but deprecated)
if let latency = viewModel.latencyMs {
    print("Latency: \(latency)ms")
}

// New code (recommended)
if let rtt = viewModel.rttMs {
    print("Network RTT: \(rtt)ms")
}

// If you need HTTP response time
if let response = viewModel.responseTimeMs {
    print("HTTP Response: \(response)ms")
}

// Show both for debugging
if let rtt = viewModel.rttMs, let response = viewModel.responseTimeMs {
    let overhead = response - rtt
    print("RTT: \(rtt)ms, HTTP: \(response)ms, Overhead: \(overhead)ms")
}
```

---

## Questions?

For issues or questions:
1. Check test suite: `SpeedTestValidationTests.swift`
2. Run diagnostics on macOS: `viewModel.runDiagnostics()`
3. Compare with terminal tools using commands above
4. Check implementation details in service files

---

*Last updated: February 2026*
