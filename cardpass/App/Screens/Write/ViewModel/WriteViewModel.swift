//
//  WriteViewModel.swift
//  cardpass
//
//  Created by Joaquín Trujillo on 30/7/25.
//
import Foundation
import SwiftUI
import LocalAuthentication
import CryptoKit

class WriteViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var site: String = ""
    @Published var passwordShown: Bool = false
    private let keyTag = "com.joaquin.cardpass.symetric.key"
    
    func writeToTag() {
        authenticateUser { [weak self] success in
            guard success, let self = self else { return }
            
            let passwordObject = Password(
                id: UUID(),
                email: self.email,
                password: self.password,
                site: self.site,
                createdAt: Date()
            )
            
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(passwordObject)
                
                let key = try self.getOrCreateSymmetricKey()
                let sealedData = try self.encrypt(data: jsonData, with: key)
                
                // Aquí debes implementar la lógica real de escritura NFC usando Core NFC
                print("Encrypted payload listo para escribir:", sealedData.base64EncodedString())
                
            } catch {
                print("Error al cifrar o preparar el contenido:", error)
            }
        }
    }
    
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authentication required to write on tag") { succes, _ in
                DispatchQueue.main.async {
                    completion(succes)
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
            kSecAttrAccessible as String: kSecAttrKeyType,
            kSecReturnData as String: true,
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
