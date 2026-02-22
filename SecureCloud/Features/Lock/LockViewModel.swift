import Foundation
import LocalAuthentication
import SwiftUI

// MARK: - LockViewModelProtocol

protocol LockViewModelProtocol: ObservableObject {
    var isAuthenticating: Bool { get }
    var authFailed: Bool { get }
    var showFallback: Bool { get }
    var pinInput: String { get set }
    func authenticate(onSuccess: @escaping () -> Void)
    func authenticateWithPin(pin: String, onSuccess: @escaping () -> Void)
}

// MARK: - LockViewModel

@MainActor
final class LockViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isAuthenticating: Bool = false
    @Published var authFailed: Bool = false
    @Published var showFallback: Bool = false
    @Published var pinInput: String = ""
    @Published var biometryType: BiometryType = .none

    // MARK: - BiometryType

    enum BiometryType {
        case faceID
        case touchID
        case none

        var icon: String {
            switch self {
            case .faceID:  return "faceid"          // SF: faceid
            case .touchID: return "touchid"         // SF: touchid
            case .none:    return "lock.fill"        // SF: lock.fill
            }
        }

        var label: String {
            switch self {
            case .faceID:  return "Use Face ID"
            case .touchID: return "Use Touch ID"
            case .none:    return "Enter Passcode"
            }
        }
    }

    // MARK: - Init

    init() {
        detectBiometryType()
    }

    // MARK: - Biometry Detection

    private func detectBiometryType() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometryType = .none
            showFallback = true
            return
        }
        switch context.biometryType {
        case .faceID:  biometryType = .faceID
        case .touchID: biometryType = .touchID
        default:       biometryType = .none
        }
    }

    // MARK: - Biometric Authentication

    func authenticate(onSuccess: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            showFallback = true
            return
        }

        isAuthenticating = true
        authFailed = false

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock your SecureCloud vault"
        ) { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isAuthenticating = false
                if success {
                    onSuccess()
                } else {
                    self.authFailed = true
                    self.showFallback = true
                }
            }
        }
    }

    // MARK: - Passcode Fallback

    func authenticateWithPin(pin: String, onSuccess: @escaping () -> Void) {
        // In production: validate pin against KeychainService
        // For MVP: any 6-digit pin succeeds (replace with real validation)
        guard pin.count == 6 else {
            authFailed = true
            return
        }
        onSuccess()
    }

    func clearPin() {
        pinInput = ""
        authFailed = false
    }
}
