import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @Environment(TimebaseStore.self) private var store
    @State private var step = 0
    @StateObject private var location = LocationProbe()

    var body: some View {
        ZStack {
            OnboardingBackdrop()

            Group {
                switch step {
                case 0:
                    WordmarkScreen(
                        onPrimary: {
                            location.requestPermission()
                            advance()
                        },
                        onSkip: { advance() }
                    )
                default:
                    GestureCalendarScreen(
                        onPrimary: {
                            Task {
                                await store.requestCalendarAccess()
                                finish()
                            }
                        },
                        onSecondary: { finish() }
                    )
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .onChange(of: location.tz) { _, tz in
            if let tz {
                store.seedDefaultsIfEmpty(localTimezone: tz)
            }
        }
    }

    private func advance() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step += 1 }
    }
    private func finish() {
        store.seedDefaultsIfEmpty()
        store.completeOnboarding()
    }
}

// MARK: - Backdrop

/// Slowly cycling palette gradient + grain + flutes. The colors drift through
/// the 24h palette so the screen feels alive without being noisy.
private struct OnboardingBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    @State private var phase: Double = 6  // start at morning-ish

    private let cycleDuration: TimeInterval = 14

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(TimeColor.background(forHour: phase, scheme: scheme).cgColor!),
                    Color(TimeColor.background(forHour: phase + 4, scheme: scheme).cgColor!),
                ],
                startPoint: .top, endPoint: .bottom
            )

            Image("flutes")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.18)

            Image("grain")
                .resizable(resizingMode: .tile)
                .blendMode(.softLight)
                .opacity(0.9)
            Image("grain")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.4)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: cycleDuration).repeatForever(autoreverses: false)) {
                phase = phase + 24
            }
        }
    }
}

// MARK: - Screen 1

private struct WordmarkScreen: View {
    let onPrimary: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Spacer()

            VStack(spacing: 14) {
                Text("Timebase")
                    .font(.custom("CrimsonText-SemiBold", size: 72))
                    .kerning(-0.6)
                    .foregroundStyle(.primary)

                Text("A quieter way to think across timezones.")
                    .font(.custom("DepartureMono-Regular", size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary.opacity(0.75))
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Haptics.buttonPressed()
                    onPrimary()
                } label: {
                    Text("Where are you?")
                        .font(.custom("DepartureMono-Regular", size: 14))
                        .padding(.horizontal, 28)
                        .frame(height: 46)
                }
                .buttonStyle(SkeuomorphicPillButtonStyle())

                Button(action: onSkip) {
                    Text("Skip")
                        .font(.custom("DepartureMono-Regular", size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
                        .padding(.vertical, 8)
                }
            }
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Screen 2

private struct GestureCalendarScreen: View {
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    @State private var pulseUp = false
    @State private var pulseRight = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Header pair
            VStack(spacing: 10) {
                Text("Two gestures")
                    .font(.custom("CrimsonText-SemiBold", size: 36))
                    .kerning(-0.3)

                Text("Drag up & down to scrub time.\nSwipe left & right to navigate.")
                    .font(.custom("DepartureMono-Regular", size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary.opacity(0.75))
                    .padding(.horizontal, 32)
            }

            // Gesture indicators — animated arrows
            HStack(spacing: 36) {
                gestureGlyph(axis: .vertical, pulse: pulseUp)
                gestureGlyph(axis: .horizontal, pulse: pulseRight)
            }
            .padding(.top, 12)

            Spacer()

            // Calendar opt-in
            VStack(spacing: 10) {
                Text("Want event countdowns too?")
                    .font(.custom("DepartureMono-Regular", size: 13))
                    .foregroundStyle(.primary.opacity(0.75))

                Button {
                    Haptics.buttonPressed()
                    onPrimary()
                } label: {
                    Text("Connect Calendar")
                        .font(.custom("DepartureMono-Regular", size: 14))
                        .padding(.horizontal, 28)
                        .frame(height: 46)
                }
                .buttonStyle(SkeuomorphicPillButtonStyle())

                Button(action: onSecondary) {
                    Text("Maybe later")
                        .font(.custom("DepartureMono-Regular", size: 12))
                        .foregroundStyle(.primary.opacity(0.6))
                        .padding(.vertical, 8)
                }
            }
            .padding(.bottom, 56)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulseUp = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.4)) {
                pulseRight = true
            }
        }
    }

    @ViewBuilder
    private func gestureGlyph(axis: Axis, pulse: Bool) -> some View {
        let isVertical = axis == .vertical
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.primary.opacity(0.35), lineWidth: 0.5)
                .frame(width: 80, height: 80)
            VStack(spacing: 4) {
                Image(systemName: isVertical ? "arrow.up" : "arrow.left")
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: isVertical ? "arrow.down" : "arrow.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.primary.opacity(0.85))
            .offset(
                y: isVertical ? (pulse ? -3 : 3) : 0,
                // (SwiftUI Y-only offset for vertical; horizontal handled with rotation below if we ever need)
            )
            .scaleEffect(isVertical ? 1 : 1)
            // Horizontal pulse via offset.x — re-layout the arrows side-by-side
            .modifier(HStackForHorizontal(active: !isVertical, pulse: pulse))
        }
        .frame(width: 80, height: 80)
    }
}

private enum Axis { case vertical, horizontal }

/// Re-arranges arrows horizontally + applies horizontal pulse for the
/// "swipe left/right" glyph. (SwiftUI ViewModifiers must conform to ViewModifier;
/// this composes the layout switch cleanly.)
private struct HStackForHorizontal: ViewModifier {
    let active: Bool
    let pulse: Bool
    func body(content: Content) -> some View {
        if active {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left").font(.system(size: 14, weight: .medium))
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.primary.opacity(0.85))
            .offset(x: pulse ? -3 : 3)
        } else {
            content
        }
    }
}

// MARK: - Location probe (unchanged)

@MainActor
final class LocationProbe: ObservableObject {
    @Published var tz: TimeZone?
    private let manager = CLLocationManager()
    private let delegate = Delegate()

    init() {
        manager.delegate = delegate
        delegate.onUpdate = { [weak self] tz in
            self?.tz = tz
        }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    private final class Delegate: NSObject, CLLocationManagerDelegate {
        var onUpdate: ((TimeZone) -> Void)?
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            onUpdate?(TimeZone.current)
        }
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
    }
}
