import SwiftUI
import AppKit

// MARK: - Paper Widget Container

public struct PaperWidgetBackground: View {
    public var isDark: Bool = false
    public var cornerRadius: CGFloat = 26

    public init(isDark: Bool = false, cornerRadius: CGFloat = 26) {
        self.isDark = isDark
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        ZStack {
            if isDark {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.16, blue: 0.18),
                                Color(red: 0.12, green: 0.12, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.975, green: 0.975, blue: 0.98),
                                Color(red: 0.94, green: 0.94, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.75)
                    )
            }
        }
        .shadow(
            color: isDark ? Color.black.opacity(0.4) : Color.black.opacity(0.08),
            radius: 14,
            x: 0,
            y: 7
        )
        .shadow(
            color: isDark ? Color.black.opacity(0.2) : Color.black.opacity(0.03),
            radius: 3,
            x: 0,
            y: 1
        )
    }
}

// MARK: - Vinyl Record

private struct VinylGrooveSpec {
    let ratio: CGFloat
    let color: Color
    let width: CGFloat
}

private let deckGrooves: [VinylGrooveSpec] = [
    VinylGrooveSpec(ratio: 0.94, color: .white.opacity(0.05), width: 0.8),
    VinylGrooveSpec(ratio: 0.89, color: .white.opacity(0.04), width: 0.6),
    VinylGrooveSpec(ratio: 0.86, color: .white.opacity(0.06), width: 0.5),
    VinylGrooveSpec(ratio: 0.83, color: .white.opacity(0.03), width: 0.5),
    VinylGrooveSpec(ratio: 0.80, color: .white.opacity(0.05), width: 0.6),
    VinylGrooveSpec(ratio: 0.77, color: .white.opacity(0.04), width: 0.5),
    VinylGrooveSpec(ratio: 0.74, color: .black.opacity(0.60), width: 1.2),
    VinylGrooveSpec(ratio: 0.71, color: .white.opacity(0.05), width: 0.6),
    VinylGrooveSpec(ratio: 0.68, color: .white.opacity(0.03), width: 0.5),
    VinylGrooveSpec(ratio: 0.65, color: .white.opacity(0.06), width: 0.5),
    VinylGrooveSpec(ratio: 0.62, color: .white.opacity(0.04), width: 0.6),
    VinylGrooveSpec(ratio: 0.59, color: .white.opacity(0.03), width: 0.5),
    VinylGrooveSpec(ratio: 0.56, color: .black.opacity(0.60), width: 1.2),
    VinylGrooveSpec(ratio: 0.53, color: .white.opacity(0.05), width: 0.6),
    VinylGrooveSpec(ratio: 0.50, color: .white.opacity(0.03), width: 0.5),
    VinylGrooveSpec(ratio: 0.47, color: .white.opacity(0.06), width: 0.5),
    VinylGrooveSpec(ratio: 0.44, color: .white.opacity(0.04), width: 0.5),
    VinylGrooveSpec(ratio: 0.40, color: .white.opacity(0.05), width: 0.8),
    VinylGrooveSpec(ratio: 0.38, color: .black.opacity(0.50), width: 1.5),
]

public struct DetailedVinylRecordView: View {
    public var diameter: CGFloat
    public var artwork: NSImage?
    public var artworkURL: URL?
    public var rotationAngle: Double = 0

    public init(
        diameter: CGFloat,
        artwork: NSImage? = nil,
        artworkURL: URL? = nil,
        rotationAngle: Double = 0
    ) {
        self.diameter = diameter
        self.artwork = artwork
        self.artworkURL = artworkURL
        self.rotationAngle = rotationAngle
    }

    public var body: some View {
        let labelDiameter = diameter * 0.35
        let spindleRingDiameter = labelDiameter * 0.30
        let spindleHoleDiameter = spindleRingDiameter * 0.42

        ZStack {
            Circle()
                .fill(Color.black.opacity(0.40))
                .frame(width: diameter, height: diameter)
                .offset(y: 4)
                .blur(radius: 6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.08, green: 0.08, blue: 0.09),
                            Color(red: 0.04, green: 0.04, blue: 0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    Color.white.opacity(0.03),
                                    Color.black.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )

            ZStack {
                ForEach(deckGrooves.indices, id: \.self) { index in
                    let groove = deckGrooves[index]
                    Circle()
                        .strokeBorder(groove.color, lineWidth: groove.width)
                        .frame(width: diameter * groove.ratio, height: diameter * groove.ratio)
                }

                // Center album art label
                ZStack {
                    if let artwork = artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: labelDiameter, height: labelDiameter)
                            .clipShape(Circle())
                    } else if let artworkURL = artworkURL {
                        CachedAsyncImage(url: artworkURL) { img in
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: labelDiameter, height: labelDiameter)
                                .clipShape(Circle())
                        } placeholder: {
                            DefaultVinylLabel(diameter: labelDiameter)
                        }
                    } else {
                        DefaultVinylLabel(diameter: labelDiameter)
                    }

                    // Label Edge Rim
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.0)
                        .frame(width: labelDiameter, height: labelDiameter)

                    // Spindle Ring (Silver metallic washer)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.90, green: 0.90, blue: 0.93),
                                    Color(red: 0.65, green: 0.65, blue: 0.68),
                                    Color(red: 0.95, green: 0.95, blue: 0.98),
                                    Color(red: 0.50, green: 0.50, blue: 0.53)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: spindleRingDiameter, height: spindleRingDiameter)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)

                    // Spindle Center Hole
                    Circle()
                        .fill(Color(red: 0.05, green: 0.05, blue: 0.06))
                        .frame(width: spindleHoleDiameter, height: spindleHoleDiameter)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.8), lineWidth: 0.5)
                        )
                }
            }
            .rotationEffect(.degrees(rotationAngle))

            // Specular highlight across the grooved surface (kept outside the paper label)
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.14), location: 0.12),
                            .init(color: .white.opacity(0.04), location: 0.18),
                            .init(color: .clear, location: 0.28),
                            .init(color: .clear, location: 0.50),
                            .init(color: .white.opacity(0.14), location: 0.62),
                            .init(color: .white.opacity(0.04), location: 0.68),
                            .init(color: .clear, location: 0.78),
                            .init(color: .clear, location: 1.0)
                        ]),
                        center: .center
                    )
                )
                .frame(width: diameter, height: diameter)
                .mask(
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: diameter * 0.96, height: diameter * 0.96)
                        Circle()
                            .fill(Color.black)
                            .frame(width: labelDiameter, height: labelDiameter)
                    }
                    .compositingGroup()
                    .luminanceToAlpha()
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Default Vinyl Label
public struct DefaultVinylLabel: View {
    public var diameter: CGFloat

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.18, green: 0.35, blue: 0.68),
                            Color(red: 0.10, green: 0.20, blue: 0.44)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )
                .frame(width: diameter, height: diameter)

            VStack(spacing: 2) {
                Text("HIGH FIDELITY")
                    .font(.system(size: max(5, diameter * 0.08), weight: .black))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(1.0)

                Text("33 ⅓ RPM")
                    .font(.system(size: max(4, diameter * 0.06), weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))

                Spacer().frame(height: diameter * 0.24)

                Text("STEREO")
                    .font(.system(size: max(4.5, diameter * 0.07), weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(width: diameter * 0.9, height: diameter * 0.9)
        }
    }
}

// MARK: - Tonearm

public struct TonearmSWand: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let startX = rect.midX
        path.move(to: CGPoint(x: startX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: startX - rect.width * 0.16, y: rect.maxY),
            control1: CGPoint(x: startX + rect.width * 0.18, y: rect.minY + rect.height * 0.35),
            control2: CGPoint(x: startX - rect.width * 0.08, y: rect.minY + rect.height * 0.70)
        )
        return path
    }
}

public struct DetailedTonearmView: View {
    public var height: CGFloat
    public var isPlaying: Bool
    public var isDark: Bool = false

    public init(height: CGFloat, isPlaying: Bool, isDark: Bool = false) {
        self.height = height
        self.isPlaying = isPlaying
        self.isDark = isDark
    }

    public var body: some View {
        let baseSize = max(16.0, height * 0.28)
        let pivotSize = baseSize * 0.70
        let armAngle: Double = isPlaying ? 24.0 : 2.0
        let wandLength = height * 0.78
        let wandThickness = max(2.2, height * 0.026)
        let headshellLen = max(12.0, height * 0.15)
        let headshellWidth = max(5.0, height * 0.065)
        let rearStubLen = height * 0.20
        let weightWidth = max(8.0, height * 0.13)
        let weightHeight = max(10.0, height * 0.14)

        ZStack(alignment: .top) {
            // Stationary Tonearm Base & Rest Clip
            ZStack {
                // Mounting flange
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isDark ? [
                                Color(white: 0.24),
                                Color(white: 0.14)
                            ] : [
                                Color(white: 0.88),
                                Color(white: 0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: baseSize, height: baseSize)
                    .overlay(
                        Circle().strokeBorder(isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.2), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)

                // Arm Rest Post & Cradle (stationary, where arm sits when stopped)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer().frame(width: wandThickness * 1.6)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isDark ? Color(white: 0.45) : Color(white: 0.35))
                            .frame(width: 2, height: 6)
                    }
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isDark ? Color(white: 0.3) : Color(white: 0.5))
                        .frame(width: 3, height: wandLength * 0.35)
                }
                .offset(x: baseSize * 0.36, y: baseSize * 0.5 + wandLength * 0.18)

                // Cueing lifter platform
                Capsule()
                    .fill(isDark ? Color(white: 0.25) : Color(white: 0.6))
                    .frame(width: baseSize * 0.8, height: 2.5)
                    .offset(x: -baseSize * 0.08, y: baseSize * 0.38)
            }
            .frame(width: baseSize, height: baseSize)
            .offset(y: rearStubLen)

            // Rotating tonearm assembly
            VStack(spacing: 0) {
                // Counterweight & rear stub
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.95), Color(white: 0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: wandThickness * 1.1, height: rearStubLen)

                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(white: 0.18))
                            .frame(width: weightWidth * 0.9, height: weightHeight * 0.32)
                            .overlay(
                                HStack(spacing: 2) {
                                    ForEach(0..<3) { _ in
                                        Rectangle().fill(Color.white.opacity(0.5)).frame(width: 0.8, height: 3)
                                    }
                                }
                            )

                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.92),
                                        Color(white: 0.68),
                                        Color(white: 0.45)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: weightWidth, height: weightHeight * 0.68)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(Color.black.opacity(0.25), lineWidth: 0.6)
                            )
                    }
                    .shadow(color: Color.black.opacity(0.35), radius: 2, x: 1, y: 1)
                    .offset(y: 2)
                }
                .frame(height: rearStubLen)

                // Gimbal bearing housing
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.96),
                                    Color(white: 0.70),
                                    Color(white: 0.85),
                                    Color(white: 0.50)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: pivotSize, height: pivotSize)
                        .overlay(
                            Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 0.7)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)

                    Rectangle()
                        .fill(Color(white: 0.28))
                        .frame(width: pivotSize * 0.75, height: 2.2)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(white: 0.4), Color(white: 0.15)],
                                center: .center,
                                startRadius: 0,
                                endRadius: pivotSize * 0.2
                            )
                        )
                        .frame(width: pivotSize * 0.38, height: pivotSize * 0.38)
                }
                .frame(width: pivotSize, height: pivotSize)

                // Tonearm S-wand
                ZStack(alignment: .top) {
                    TonearmSWand()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.98),
                                    Color(white: 0.82),
                                    Color(white: 0.58)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: wandThickness, lineCap: .round)
                        )
                        .frame(width: wandLength * 0.25, height: wandLength)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 1.5, y: 1.5)

                    VStack(spacing: 0) {
                        Spacer().frame(height: wandLength - 2)

                        RoundedRectangle(cornerRadius: 0.8)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.9), Color(white: 0.45)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: wandThickness * 1.5, height: 3.5)

                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.22, green: 0.22, blue: 0.25),
                                            Color(red: 0.10, green: 0.10, blue: 0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: headshellWidth, height: headshellLen)
                                .overlay(
                                    Rectangle()
                                        .fill(Color.white.opacity(0.55))
                                        .frame(width: 1.0, height: headshellLen * 0.85),
                                    alignment: .leading
                                )
                                .shadow(color: Color.black.opacity(0.4), radius: 2, x: 1, y: 1)

                            Path { p in
                                p.move(to: CGPoint(x: headshellWidth * 0.7, y: headshellLen * 0.25))
                                p.addQuadCurve(
                                    to: CGPoint(x: headshellWidth * 1.45, y: headshellLen * 0.55),
                                    control: CGPoint(x: headshellWidth * 1.4, y: headshellLen * 0.2)
                                )
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [Color(white: 0.92), Color(white: 0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.2
                            )

                            Circle()
                                .fill(Color(red: 0.96, green: 0.22, blue: 0.22))
                                .frame(width: max(2.5, height * 0.026), height: max(2.5, height * 0.026))
                                .offset(x: -headshellWidth * 0.2, y: headshellLen + 0.5)
                        }
                        .rotationEffect(.degrees(-20))
                    }
                }
            }
            .rotationEffect(
                .degrees(armAngle),
                anchor: UnitPoint(
                    x: 0.5,
                    y: (rearStubLen + pivotSize * 0.5) / (rearStubLen + pivotSize + wandLength + headshellLen)
                )
            )
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPlaying)
        }
        .frame(width: max(baseSize, height * 0.35), height: rearStubLen + pivotSize + wandLength + headshellLen)
    }
}

// MARK: - Tactile Vertical Slider
public struct TactileVerticalSlider: View {
    @Binding public var value: Float // 0.0 to 1.0
    public var isDark: Bool = false
    public var height: CGFloat = 46
    public var width: CGFloat = 16

    public init(value: Binding<Float>, isDark: Bool = false, height: CGFloat = 46, width: CGFloat = 16) {
        self._value = value
        self.isDark = isDark
        self.height = height
        self.width = width
    }

    public var body: some View {
        let thumbHeight: CGFloat = width * 1.15
        let trackHeight: CGFloat = max(10, height - thumbHeight)

        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Recessed Groove Track
                Capsule(style: .continuous)
                    .fill(
                        isDark
                            ? Color(red: 0.08, green: 0.08, blue: 0.10)
                            : Color(red: 0.18, green: 0.18, blue: 0.20)
                    )
                    .frame(width: width, height: height)
                    .overlay(
                        // Inner Inset Shadow
                        Capsule(style: .continuous)
                            .strokeBorder(Color.black.opacity(0.4), lineWidth: 0.8)
                    )

                // White / Cream Tactile Thumb Knob
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.98, blue: 1.0),
                                Color(red: 0.91, green: 0.91, blue: 0.93)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width - 2.5, height: thumbHeight)
                    .overlay(
                        // Grip notch on thumb
                        Capsule()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: width * 0.45, height: 1.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.8), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 2.5, x: 0, y: 1.5)
                    .offset(y: -CGFloat(max(0, min(1, value))) * trackHeight)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let locationY = gesture.location.y
                        let invertedY = height - locationY - (thumbHeight / 2)
                        let progress = Float(max(0, min(1, invertedY / trackHeight)))
                        value = progress
                    }
            )
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Tactile Paper Playback Controls
public struct TactilePaperControls: View {
    public var isPlaying: Bool
    public var isDark: Bool = false
    public var onPrevious: () -> Void
    public var onTogglePlayPause: () -> Void
    public var onNext: () -> Void

    public init(
        isPlaying: Bool,
        isDark: Bool = false,
        onPrevious: @escaping () -> Void,
        onTogglePlayPause: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.isPlaying = isPlaying
        self.isDark = isDark
        self.onPrevious = onPrevious
        self.onTogglePlayPause = onTogglePlayPause
        self.onNext = onNext
    }

    public var body: some View {
        HStack(spacing: 18) {
            // Previous Track Button
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isDark ? Color.white.opacity(0.85) : Color(red: 0.2, green: 0.2, blue: 0.22))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)

            // Play / Pause Tactile Button
            Button(action: onTogglePlayPause) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isDark ? [
                                    Color(red: 0.28, green: 0.28, blue: 0.32),
                                    Color(red: 0.18, green: 0.18, blue: 0.22)
                                ] : [
                                    Color(red: 0.98, green: 0.98, blue: 1.0),
                                    Color(red: 0.90, green: 0.90, blue: 0.92)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.9),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isDark ? Color.black.opacity(0.4) : Color.black.opacity(0.12),
                            radius: 4,
                            x: 0,
                            y: 2
                        )

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isDark ? .white : Color(red: 0.15, green: 0.15, blue: 0.18))
                        .offset(x: isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)

            // Next Track Button
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isDark ? Color.white.opacity(0.85) : Color(red: 0.2, green: 0.2, blue: 0.22))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
