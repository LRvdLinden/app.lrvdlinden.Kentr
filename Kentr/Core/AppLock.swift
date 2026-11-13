import SwiftUI
import LocalAuthentication

/// App-vergrendeling met Face ID / Touch ID (met toegangscode als terugval).
@MainActor
final class AppLock: ObservableObject {
    private static let key = "security.faceID"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating = false
    @Published var lastError: String?

    init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.key)
        isEnabled = enabled
        isLocked = enabled
    }

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "toegangscode"
        }
    }

    var biometrySymbol: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "faceid"
        }
    }

    var canUseAuthentication: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        if await authenticate(reason: "Ontgrendel Kentr om je auto's te bekijken.") {
            isLocked = false
        }
    }

    /// Zet de vergrendeling aan of uit; vraagt eerst om bevestiging.
    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }
        let reason = enabled ? "Bevestig om de app-vergrendeling aan te zetten."
                             : "Bevestig om de app-vergrendeling uit te zetten."
        guard await authenticate(reason: reason) else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.key)
        if !enabled { isLocked = false }
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Annuleer"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = "Op dit apparaat is geen Face ID, Touch ID of toegangscode ingesteld."
            return false
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            lastError = nil
            return ok
        } catch {
            return false
        }
    }
}
