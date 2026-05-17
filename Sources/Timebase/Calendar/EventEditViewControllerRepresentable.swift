import SwiftUI
import EventKit
import EventKitUI

/// Wraps Apple's native EKEventEditViewController so we can present it from
/// SwiftUI. Caller passes a pre-filled EKEvent + the EKEventStore; we hand
/// it to Apple's editor and call back on save/cancel.
struct EventEditViewControllerRepresentable: UIViewControllerRepresentable {
    let event: EKEvent
    let eventStore: EKEventStore
    let onDone: @Sendable @MainActor (EKEventEditViewAction) -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let vc = EKEventEditViewController()
        vc.eventStore = eventStore
        vc.event = event
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: @Sendable @MainActor (EKEventEditViewAction) -> Void
        init(onDone: @escaping @Sendable @MainActor (EKEventEditViewAction) -> Void) {
            self.onDone = onDone
        }

        nonisolated func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            let handler = self.onDone
            Task { @MainActor in
                controller.dismiss(animated: true) {
                    handler(action)
                }
            }
        }
    }
}
