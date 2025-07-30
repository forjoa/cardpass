import Foundation
import LocalAuthentication
import CryptoKit
import CoreNFC
import Combine

class ReadViewModel: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var passwords: [Password] = []
    @Published var isLoading: Bool = false
    @Published var firstTime: Bool = true
    private var nfcSession: NFCNDEFReaderSession?
    private let keyTag = "com.joaquin.cardpass.symetric.key"

    func readTag() {
        authenticateUser { [weak self] success in
            guard success, let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = true
                self.firstTime = false
                self.startNFCSession()
            }
        }
    }

    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: "Authentication required to read NFC tag") { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }

    private func startNFCSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("NFC reading not available")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        nfcSession?.alertMessage = "Place your NFC tag near the device."
        nfcSession?.begin()
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
        }
        print("NFC session invalidated:", error.localizedDescription)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async {
            self.isLoading = false
        }

        guard let message = messages.first else { return }
        for record in message.records {
            if let decryptedPassword = try? decryptRecord(record) {
                DispatchQueue.main.async {
                    self.passwords.append(decryptedPassword)
                }
            }
        }
    }

    private func decryptRecord(_ record: NFCNDEFPayload) throws -> Password {
        let key = try getSymmetricKey()
        guard let encryptedData = record.payload as Data? else {
            throw NSError(domain: "NFCError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No payload data"])
        }
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        let password = try JSONDecoder().decode(Password.self, from: decryptedData)
        return password
    }

    private func getSymmetricKey() throws -> SymmetricKey {
        let tag = keyTag.data(using: .utf8)!

        let query: [String: Any] = [
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
        throw NSError(domain: "KeychainError", code: Int(status), userInfo: nil)
    }
}
