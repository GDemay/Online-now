import SwiftUI

/// Custom logo view that recreates the Online Now logo
/// Ring with checkmark and glowing green center dot
@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
public struct LogoView: View {
    let size: CGFloat
    let isAnimating: Bool
    let isOnline: Bool

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5

    public init(size: CGFloat = 200, isAnimating: Bool = false, isOnline: Bool = true) {
        self.size = size
        self.isAnimating = isAnimating
        self.isOnline = isOnline
    }

    public var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (isOnline ? Color.green : Color.red).opacity(glowOpacity * 0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(pulseScale)

            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.28, green: 0.33, blue: 0.42),
                            Color(red: 0.35, green: 0.40, blue: 0.48)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round)
                )
                .frame(width: size * 0.7, height: size * 0.7)
                .rotationEffect(.degrees(isAnimating ? rotation : 0))

            // Ring gap with checkmark
            if isOnline && !isAnimating {
                CheckmarkBadge(size: size * 0.12)
                    .offset(x: size * 0.28, y: -size * 0.18)
            }

            // Center glowing dot
            ZStack {
                // Glow layers
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isOnline ? Color.green : Color.red).opacity(0.6),
                                (isOnline ? Color.green : Color.red).opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.25
                        )
                    )
                    .frame(width: size * 0.5, height: size * 0.5)
                    .scaleEffect(pulseScale)

                // Main dot
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isOnline
                                ? [Color(red: 0.3, green: 0.85, blue: 0.45), Color(red: 0.2, green: 0.7, blue: 0.35)]
                                : [Color(red: 0.9, green: 0.3, blue: 0.3), Color(red: 0.7, green: 0.2, blue: 0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.28, height: size * 0.28)
                    .shadow(color: (isOnline ? Color.green : Color.red).opacity(0.5), radius: size * 0.05, x: 0, y: size * 0.02)
            }
        }
        .onAppear {
            if isAnimating {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
                glowOpacity = 0.8
            }
        }
    }
}

/// Small checkmark badge for the logo
struct CheckmarkBadge: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: size * 1.5, height: size * 1.5)

            Image(systemName: "checkmark")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Color(red: 0.28, green: 0.33, blue: 0.42))
        }
    }
}

/// Loading indicator that matches the logo style
@available(iOS 17.0, *)
public struct LoadingRingView: View {
    let size: CGFloat
    @State private var rotation: Double = 0

    public init(size: CGFloat = 200) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: size * 0.06)
                .frame(width: size * 0.7, height: size * 0.7)

            // Animated arc
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round)
                )
                .frame(width: size * 0.7, height: size * 0.7)
                .rotationEffect(.degrees(rotation))

            // Center pulsing dot
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: size * 0.28, height: size * 0.28)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

#if os(iOS)
@available(iOS 17.0, *)
#Preview {
    VStack(spacing: 40) {
        LogoView(size: 200, isAnimating: false, isOnline: true)
        LogoView(size: 150, isAnimating: false, isOnline: false)
        LoadingRingView(size: 150)
    }
    .padding()
    .background(Color(.systemBackground))
}
#endif
