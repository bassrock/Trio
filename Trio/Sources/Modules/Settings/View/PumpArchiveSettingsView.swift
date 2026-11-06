import LoopKitUI
import PumpArchiveKit
import SwiftUI

/// PumpArchiveKit's own settings screen (server, token, upload switch, "Upload now"), shown as a
/// sheet from Settings → Services. It closes when that screen reports it's done.
struct PumpArchiveSettingsView: UIViewControllerRepresentable {
    let service: PumpArchiveService
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> UIViewController {
        var viewController = service.settingsViewController(colorPalette: .default)
        viewController.completionDelegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}

    final class Coordinator: CompletionDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func completionNotifyingDidComplete(_: CompletionNotifying) { onDone() }
    }
}
