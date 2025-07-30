import Foundation
import SwiftUI
import LocalAuthentication
import CryptoKit
import CoreNFC

class WriteViewModel: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var site: String = ""
    @Published var passwordShown: Bool = false
    @Published var isWriting: Bool = false

    private let keyTag = "com.joaquin.cardpass.symetric.key"
    private var nfcSession: NFCNDEFReaderSession?

    func writeToTag() {
        authenticateUser { [weak self] success in
            guard success, let self = self else { return }
            DispatchQueue.main.async {
                self.isWriting = true
                self.startNFCSession()
            }
        }
    }

    private func startNFCSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("NFC not available")
            DispatchQueue.main.async {
                self.isWriting = false
            }
            return
        }
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "Approach your NFC tag to write the password."
        nfcSession?.begin()
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isWriting = false
        }
        print("NFC session invalidated:", error.localizedDescription)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not used here
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No NFC tag detected")
            return
        }

        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.isWriting = false }
                return
            }

            do {
                let passwordObject = Password(
                    id: UUID(),
                    email: self.email,
                    password: self.password,
                    site: self.site,
                    createdAt: Date()
                )
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(passwordObject)

                let key = try self.getOrCreateSymmetricKey()
                let sealedData = try self.encrypt(data: jsonData, with: key)
                let payload = NFCNDEFPayload(format: .unknown, type: Data(), identifier: Data(), payload: sealedData)

                let message = NFCNDEFMessage(records: [payload])

                tag.writeNDEF(message) { error in
                    if let error = error {
                        session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                        DispatchQueue.main.async { self.isWriting = false }
                    } else {
                        session.alertMessage = "Password successfully written."
                        session.invalidate()
                        DispatchQueue.main.async { self.isWriting = false }
                    }
                }

            } catch {
                session.invalidate(errorMessage: "Error encoding or encrypting data")
                DispatchQueue.main.async { self.isWriting = false }
            }
        }
    }

    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: "Authentication required to write on tag") { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }

    private func getOrCreateSymmetricKey() throws -> SymmetricKey {
        let tag = keyTag.data(using: .utf8)!

        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyType,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let keyData = item as? Data {
            return SymmetricKey(data: keyData)
        }

        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        query = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyType,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let statusAdd = SecItemAdd(query as CFDictionary, nil)
        if statusAdd != errSecSuccess {
            throw NSError(domain: "Keychain Error", code: Int(statusAdd), userInfo: nil)
        }

        return newKey
    }

    private func encrypt(data: Data, with key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "Encryption Error", code: -1, userInfo: nil)
        }
        return combined
    }
}
