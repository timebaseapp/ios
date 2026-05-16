import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @Environment(TimebaseStore.self) private var store
    @State private var step = 0
    @StateObject private var location = LocationProbe()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch step {
            case 0:
                OnboardingScreen(
                    statement: "Timebase shows time, everywhere.",
                    buttonTitle: "Where are you?",
                    secondaryTitle: "Skip"
                ) {
                    location.requestPermission()
                    advance()
                } secondaryAction: {
                    advance()
                }
            case 1:
                OnboardingScreen(
                    statement: "Drag anywhere to see what time it'll be.",
                    buttonTitle: "Continue",
                    secondaryTitle: nil
                ) {
                    advance()
                } secondaryAction: {}
            default:
                OnboardingScreen(
                    statement: "Want event countdowns too?",
                    buttonTitle: "Yes",
                    secondaryTitle: "Maybe later"
                ) {
                    Task {
                        await store.requestCalendarAccess()
                        finish()
                    }
                } secondaryAction: {
                    finish()
                }
            }
        }
        .onChange(of: location.tz) { _, tz in
            if let tz {
                store.seedDefaultsIfEmpty(localTimezone: tz)
            }
        }
    }

    private func advance() {
        withAnimation(.easeOut(duration: 0.25)) { step += 1 }
    }
    private func finish() {
        store.seedDefaultsIfEmpty()
        store.completeOnboarding()
    }
}

struct OnboardingScreen: View {
    let statement: String
    let buttonTitle: String
    let secondaryTitle: String?
    let action: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Text(statement)
                .font(.system(size: 32, weight: .light))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .frame(maxWidth: 420)
            Spacer()
            VStack(spacing: 16) {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.primary)
                if let secondaryTitle {
                    Button(secondaryTitle, action: secondaryAction)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 56)
        }
    }
}

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
            // Best-effort: use the system timezone as the local one. CLPlacemark
            // could give a more precise tz, but for first-run seed this is fine.
            onUpdate?(TimeZone.current)
        }
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
    }
}
